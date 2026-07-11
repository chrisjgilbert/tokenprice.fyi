require "json"

# Runs every 6 hours: takes the last couple of days' relevant, unattached
# news_items plus recent price-move context and asks Claude Opus to draft
# MarketEvent candidates. Writes zero or more MarketEvent rows with status:
# "draft"; a human approves or discards each draft in the admin review queue.
# Nothing automated publishes an event or creates a PricePoint.
#
# Running on a schedule means the same news could be re-presented on a later run,
# so dedup is layered:
#   • Hard guard: every item fed to the curator is stamped curated_at, so a
#     given news_item is only ever evaluated once — no re-feed, no duplicate.
#   • Soft guard: existing published events AND pending drafts are listed in the
#     prompt as "do NOT (re-)create", covering the case where a *different*
#     news_item reports an event already drafted from an earlier item.
class EventCurationJob < ApplicationJob
  queue_as :default

  MODEL      = "claude-opus-4-8"
  TOOL_NAME  = "submit_drafts"
  MAX_TOKENS = 2048
  # Comfortably wider than the run cadence so missed runs don't drop news; the
  # curated_at stamp prevents an item being re-presented regardless.
  LOOKBACK   = 2.days

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You are a market event curator for tokenprice.fyi, a site that tracks LLM API token prices.

    Your task: given a list of recent AI/ML news items, draft zero or more MarketEvent candidates
    worth publishing on the site. A MarketEvent documents a concrete pricing milestone:
      • A significant price change for a major LLM API
      • A model launch that shifted market pricing or set a new price benchmark
      • A market event (acquisition, partnership) with direct pricing implications

    Style guide — match existing events exactly:
      • Title: punchy 4–7 words, present tense, specific numbers where possible
        Good: "GPT-4 Turbo: 3× cheaper"   "Gemini Flash cuts 78%"
        Bad:  "OpenAI announces pricing changes"
      • Note: one sentence with concrete figures and source context.
        Good: "GPT-4 Turbo launches at $10/$30 per MTok with 128K context, 3× cheaper than GPT-4."
      • event_date: the date the event happened, not when it was reported.
      • confidence: 0.0–1.0; only include drafts above 0.5.

    Rules:
      • Drafting nothing is the correct outcome for a quiet period — most days produce zero drafts.
      • Never duplicate an event already in the existing published events list.
      • Never re-create something already in the pending drafts list — it is already awaiting review.
      • Dates and figures in a draft are claims to verify — always include source_url when known.
  PROMPT

  TOOL_DEFINITION = {
    name: TOOL_NAME,
    description: "Submit zero or more MarketEvent draft candidates. Submit an empty array for a quiet day.",
    input_schema: {
      type: "object",
      required: [ "drafts" ],
      properties: {
        drafts: {
          type: "array",
          items: {
            type: "object",
            required: %w[title note event_date confidence],
            properties: {
              title:         { type: "string" },
              note:          { type: "string" },
              event_date:    { type: "string", description: "ISO 8601 date YYYY-MM-DD" },
              source_url:    { type: "string" },
              confidence:    { type: "number", minimum: 0.0, maximum: 1.0 },
              news_item_ids: { type: "array", items: { type: "integer" } }
            }
          }
        }
      }
    }
  }.freeze

  def perform
    news_items = NewsItem.awaiting_curation
                         .where("published_at >= ? OR published_at IS NULL", LOOKBACK.ago)
                         .order(published_at: :desc)
                         .limit(50)
                         .to_a

    return Rails.logger.info("EventCurationJob: no candidate news items, skipping") if news_items.empty?

    candidate_ids = news_items.map(&:id)

    existing_events  = MarketEvent.published.recent_first.limit(30)
    pending_drafts   = MarketEvent.drafts.recent_first.limit(30)
    recent_releases  = AiModel.where.not(released_on: nil)
                               .where("released_on >= ?", 6.months.ago)
                               .includes(:provider)
                               .order(released_on: :desc)
                               .limit(15)

    content = build_prompt(news_items, existing_events, pending_drafts, recent_releases)

    response = client.messages.create(
      model:       MODEL,
      max_tokens:  MAX_TOKENS,
      system_:     SYSTEM_PROMPT,
      messages:    [ { role: "user", content: content } ],
      tools:       [ TOOL_DEFINITION ],
      tool_choice: { type: "tool", name: TOOL_NAME }
    )

    tool_use = response.content.find { |b| b.type == :tool_use }
    raise "EventCurationJob: no tool_use block in response" unless tool_use

    drafts = tool_use.input[:drafts] || []
    created = 0

    drafts.each do |draft|
      next unless draft[:confidence].to_f >= 0.5

      event = MarketEvent.create!(
        title:      draft[:title].to_s.truncate(255),
        note:       draft[:note].to_s,
        event_date: Date.parse(draft[:event_date].to_s),
        source_url: draft[:source_url].to_s.presence,
        status:     "draft",
        source:     "curation",
        kind:       "market"
      )

      ids = Array(draft[:news_item_ids]).map(&:to_i).select(&:positive?)
      NewsItem.where(id: ids).update_all(market_event_id: event.id) if ids.any?

      # Generate the cited "so what" out of band — a separate web-search call the
      # forced-tool curation request above can't make, kept off this job's path.
      MarketEventInsightJob.perform_later(event)
      created += 1
    rescue Date::Error, ActiveRecord::RecordInvalid => e
      Rails.logger.warn("EventCurationJob: skipping malformed draft — #{e.message}")
    end

    # Stamp every candidate we fed to the curator so it is never re-presented on
    # a later run, whether or not it became a draft. This is the hard dedup guard.
    NewsItem.where(id: candidate_ids).update_all(curated_at: Time.current)

    Rails.logger.info("EventCurationJob: created #{created} draft(s) from #{news_items.size} candidates")

    if created > 0
      SlackNotifier.post(slack_payload(created))
    end
  rescue Anthropic::Errors::Error => e
    Honeybadger.notify(e) if defined?(Honeybadger)
    raise
  end

  private

  def client
    @client ||= AnthropicClient.build
  end

  def build_prompt(news_items, existing_events, pending_drafts, recent_releases)
    parts = []

    parts << "## Candidate news items (recent, relevant, not yet attached to an event)\n\n"
    news_items.each do |item|
      date_str = item.published_at ? item.published_at.strftime("%Y-%m-%d") : "unknown date"
      parts << "[id: #{item.id}] \"#{item.title}\" (#{item.source}, #{date_str})\n"
      parts << "  Rationale: #{item.rationale}\n" if item.rationale.present?
    end

    parts << "\n## Existing published events (do NOT duplicate)\n\n"
    existing_events.each do |ev|
      parts << "#{ev.event_date.iso8601}: #{ev.title}\n"
    end

    if pending_drafts.any?
      parts << "\n## Pending drafts already awaiting review (do NOT re-create)\n\n"
      pending_drafts.each do |ev|
        parts << "#{ev.event_date.iso8601}: #{ev.title}\n"
      end
    end

    if recent_releases.any?
      parts << "\n## Recent model releases (context only)\n\n"
      recent_releases.each do |m|
        parts << "#{m.released_on.iso8601}: #{m.name} (#{m.provider.name})\n"
      end
    end

    parts.join
  end

  def slack_payload(count)
    base_url = "https://tokenprice.fyi"
    review_link = "<#{base_url}/admin/market_events|Review queue>"
    { text: "EventCurationJob drafted #{count} market event candidate#{"s" if count != 1}",
      blocks: [
        { type: "section",
          text: { type: "mrkdwn",
                  text: "*📋 #{count} draft market event#{"s" if count != 1} awaiting review*\n" \
                        "#{review_link} — approve or discard each draft in the admin." } }
      ] }
  end
end
