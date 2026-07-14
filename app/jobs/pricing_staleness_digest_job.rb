# Weekly job: audits the hand-curated directory prices via PricingStaleness and
# posts the flagged counts to Slack, so the quarterly re-verification pass is
# un-forgettable rather than dependent on someone remembering a rake task. Silent
# when nothing is flagged (every curated price fresh and dated).
class PricingStalenessDigestJob < ApplicationJob
  queue_as :default

  def perform
    groups = PricingStaleness.report
    totals = PricingStaleness.totals(groups)
    flagged = totals[:stale] + totals[:undated] + totals[:unpriced]
    return Rails.logger.info("PricingStalenessDigestJob: nothing flagged, skipping") if flagged.zero?

    SlackNotifier.post(slack_payload(groups, totals))
  end

  private

  def slack_payload(groups, totals)
    summary = "*#{totals[:stale]} stale · #{totals[:undated]} undated · " \
              "#{totals[:unpriced]} unpriced* across #{totals[:curated]} curated prices"

    blocks = [
      { type: "header",
        text: { type: "plain_text", text: "🗓️ Price freshness · #{Date.current.strftime('%-d %b %Y')}" } },
      { type: "section", text: { type: "mrkdwn", text: summary } }
    ]
    groups.each do |group|
      next if group.rows.none?(&:flagged?)

      blocks << { type: "section", text: { type: "mrkdwn", text: group_line(group) } }
    end

    { text: "Price freshness — #{Date.current.strftime('%-d %b %Y')}", blocks: blocks }
  end

  def group_line(group)
    header = "*#{group.category.label}* — #{group.stale_count} stale, " \
             "#{group.undated_count} undated, #{group.unpriced_count} unpriced"
    items = group.rows.select(&:flagged?).map do |row|
      age = row.age_days ? " (#{row.age_days}d)" : ""
      "• #{row.name} (#{row.provider_name}) — #{row.status}#{age}"
    end
    ([ header ] + items).join("\n")
  end
end
