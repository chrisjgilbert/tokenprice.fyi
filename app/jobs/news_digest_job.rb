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

  # Slack rejects a message with "invalid_blocks" (HTTP 400) when a single
  # section block's text exceeds 3000 characters. This digest accumulates every
  # unnotified item, so a backlog or a busy day can push the combined lines past
  # that limit. Keep a little headroom for safety.
  SECTION_TEXT_LIMIT = 2900

  def slack_payload(items)
    count = items.size
    summary = "*#{count} item#{"s" unless count == 1}*"
    lines   = items.map { |item| digest_line(item) }

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

  def digest_line(item)
    link = "<#{item.url}|#{item.title}>"
    if item.relevant.nil?
      "• #{link} (#{item.source}) — ⚠ unclassified"
    else
      "• #{link} (#{item.source}) — #{item.kind || "unknown"} · #{item.rationale || "—"}"
    end
  end

  # Pack newline-joined lines into chunks no longer than SECTION_TEXT_LIMIT so
  # each becomes a section block within Slack's limit. A single line longer than
  # the limit (e.g. a very long title) is truncated rather than dropped.
  def section_texts(lines)
    chunks  = []
    current = []
    length  = 0

    lines.each do |line|
      line = truncate_line(line)
      # +1 accounts for the "\n" that joins this line to the previous one.
      added = current.empty? ? line.length : line.length + 1
      if current.any? && length + added > SECTION_TEXT_LIMIT
        chunks << current.join("\n")
        current = [line]
        length  = line.length
      else
        current << line
        length  += added
      end
    end
    chunks << current.join("\n") if current.any?
    chunks
  end

  def truncate_line(line)
    return line if line.length <= SECTION_TEXT_LIMIT

    line[0, SECTION_TEXT_LIMIT - 1] + "…"
  end
end
