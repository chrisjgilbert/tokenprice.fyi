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

  # Slack rejects (400 invalid_blocks) any section block whose text exceeds
  # 3000 characters. Stay safely under that so a large backlog of items — which
  # is exactly what builds up when an earlier digest failed and notified_at was
  # never stamped — doesn't produce a payload Slack refuses on every run.
  SECTION_TEXT_LIMIT = 2900

  def slack_payload(items)
    count = items.size
    summary = "*#{count} item#{"s" unless count == 1}*"
    lines = items.map { |item| item_line(item) }

    blocks = [
      { type: "header",
        text: { type: "plain_text",
                text: "📰 News · #{Date.current.strftime('%-d %b %Y')}" } }
    ]
    section_texts([summary, *lines]).each do |text|
      blocks << { type: "section", text: { type: "mrkdwn", text: text } }
    end

    { text: "Token Price news — #{Date.current.strftime('%-d %b %Y')}",
      blocks: blocks }
  end

  def item_line(item)
    link = "<#{item.url}|#{item.title}>"
    if item.relevant.nil?
      "• #{link} (#{item.source}) — ⚠ unclassified"
    else
      "• #{link} (#{item.source}) — #{item.kind || "unknown"} · #{item.rationale || "—"}"
    end
  end

  # Pack lines into the fewest section texts that each stay under the Slack
  # limit. A single line longer than the limit is truncated so it can't wedge
  # the digest.
  def section_texts(lines)
    chunks = []
    current = +""
    lines.each do |line|
      line = "#{line[0, SECTION_TEXT_LIMIT - 1]}…" if line.length > SECTION_TEXT_LIMIT
      candidate = current.empty? ? line : "#{current}\n#{line}"
      if candidate.length > SECTION_TEXT_LIMIT
        chunks << current unless current.empty?
        current = line
      else
        current = candidate
      end
    end
    chunks << current unless current.empty?
    chunks
  end
end
