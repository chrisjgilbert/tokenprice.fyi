# Daily job: posts any relevant, unnotified NewsItems to Slack and stamps
# notified_at so they are not included in future digests.
# Runs after NewsScanJob (5am) and ReleaseWatchJob have had a chance to
# classify items. If SlackNotifier raises, notified_at is never set — items
# will be retried in the next run.
class NewsDigestJob < ApplicationJob
  queue_as :default

  def perform
    pending = NewsItem.pending_digest.to_a
    return Rails.logger.info("NewsDigestJob: no pending news items, skipping") if pending.empty?

    SlackNotifier.post(slack_payload(pending))
    NewsItem.where(id: pending.map(&:id)).update_all(notified_at: Time.current)
  end

  private

  def slack_payload(items)
    lines = items.map do |item|
      link = "<#{item.url}|#{item.title}>"
      if item.relevant.nil?
        "• #{link} (#{item.source}) — ⚠ unclassified"
      else
        "• #{link} (#{item.source}) — #{item.kind || "unknown"} · #{item.rationale || "—"}"
      end
    end
    count = items.size
    { text: "Token Price news — #{Date.current.strftime('%-d %b %Y')}",
      blocks: [
        { type: "header",
          text: { type: "plain_text",
                  text: "📰 News · #{Date.current.strftime('%-d %b %Y')}" } },
        { type: "section",
          text: { type: "mrkdwn",
                  text: "*#{count} item#{"s" unless count == 1}*\n#{lines.join("\n")}" } }
      ] }
  end
end
