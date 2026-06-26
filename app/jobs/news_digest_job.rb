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

    payload, notified = slack_payload(pending)
    SlackNotifier.post(payload)
    NewsItem.where(id: notified.map(&:id)).update_all(notified_at: Time.current)
  end

  private

  # Slack rejects a message ("invalid_blocks", HTTP 400) once a section block's
  # text exceeds 3000 characters, and separately once a message has more than 50
  # blocks. SECTION_TEXT_LIMIT keeps each section under the first limit (with a
  # little headroom); MAX_ITEM_SECTIONS keeps the whole message under the second,
  # leaving room for the header and summary blocks (50 - 2 = 48).
  SECTION_TEXT_LIMIT = 2900
  MAX_ITEM_SECTIONS  = 48

  # Returns [payload, items_included]. When a backlog overflows the block limit,
  # only the items that fit are posted; the rest keep notified_at = nil and roll
  # into the next run rather than being dropped silently.
  def slack_payload(items)
    lines  = items.map { |item| digest_line(item) }
    chunks = pack_lines(lines)

    shown_chunks = chunks.first(MAX_ITEM_SECTIONS)
    shown_count  = shown_chunks.sum(&:size)
    held_back    = items.size - shown_count

    summary = +"*#{shown_count} item#{"s" unless shown_count == 1}*"
    summary << " — #{held_back} more in the next digest" if held_back.positive?

    blocks = [
      { type: "header",
        text: { type: "plain_text",
                text: "📰 News · #{Date.current.strftime('%-d %b %Y')}" } },
      { type: "section",
        text: { type: "mrkdwn", text: summary } }
    ]
    shown_chunks.each do |chunk|
      blocks << { type: "section", text: { type: "mrkdwn", text: chunk.join("\n") } }
    end

    payload = { text: "Token Price news — #{Date.current.strftime('%-d %b %Y')}",
                blocks: blocks }
    [payload, items.first(shown_count)]
  end

  def digest_line(item)
    link = "<#{item.url}|#{item.title}>"
    if item.relevant.nil?
      "• #{link} (#{item.source}) — ⚠ unclassified"
    else
      "• #{link} (#{item.source}) — #{item.kind || "unknown"} · #{item.rationale || "—"}"
    end
  end

  # Pack lines into groups whose newline-joined length stays under
  # SECTION_TEXT_LIMIT, so each group becomes a section block within Slack's
  # limit. Returns an array of line-arrays (one per section); each input line is
  # one item, so a group's size is the number of items it covers. A single line
  # longer than the limit (e.g. a very long title) is truncated rather than dropped.
  def pack_lines(lines)
    chunks  = []
    current = []
    length  = 0

    lines.each do |line|
      line = truncate_line(line)
      # +1 accounts for the "\n" that joins this line to the previous one.
      added = current.empty? ? line.length : line.length + 1
      if current.any? && length + added > SECTION_TEXT_LIMIT
        chunks << current
        current = [line]
        length  = line.length
      else
        current << line
        length  += added
      end
    end
    chunks << current if current.any?
    chunks
  end

  def truncate_line(line)
    return line if line.length <= SECTION_TEXT_LIMIT

    line[0, SECTION_TEXT_LIMIT - 1] + "…"
  end
end
