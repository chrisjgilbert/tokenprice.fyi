# Extracts zero or more ModelCandidates from a "release"-classified NewsItem
# using Claude — the detection→curation bridge's read step. Reached through
# NewsItem#extract_model_candidates; returns an array of unsaved ModelCandidates
# (empty when the item doesn't announce an identifiable new model). Dedup against
# the existing catalog is the job's concern, not this operation's.
#
# An array, not a single candidate, because a source item can bundle several
# stories — a daily aggregator digest can announce more than one new model in a
# single item (its RSS excerpt is the whole issue, not one story).
#
# Pricing is best-effort and confidence-rated: the extractor is told to return the
# price ONLY when the headline/excerpt makes it evident, and to omit it (leaving
# the reviewer to price from source_url) rather than guess — the same "never
# publish an unconfirmed number" rule the pricing docs hold. A launch with no
# stated price still yields a candidate (identity + confidence "L"), so nothing
# slips by.
class NewsItem::ModelExtraction
  class Error < StandardError; end

  MODEL = "claude-haiku-4-5-20251001"

  CATEGORY_SLUGS = ModelCategory.all.map(&:slug).freeze

  MODEL_SCHEMA = {
    type: "object",
    properties: {
      name:         { type: "string", description: "The model's name, e.g. \"Muse Spark 1.1\"." },
      provider:     { type: "string", description: "The company that makes it, e.g. \"Meta\"." },
      category:     { type: "string", enum: CATEGORY_SLUGS + [ "other" ],
                      description: "Which pricing family: language, embeddings, rerank, speech-to-text, text-to-speech, image, video, or other." },
      confidence:   { type: "string", enum: %w[H M L],
                      description: "Confidence in the extracted fields (esp. pricing): H primary, M corroborated, L inferred." },
      released_on:  { type: "string", description: "ISO 8601 launch date YYYY-MM-DD, if stated." },
      pricing:      { type: "object",
                      description: "Only if the price is stated in the item. Per-token: input/output (USD per 1M tokens). Native: price_summary + pricing_model (per_image/per_second/per_search/…) or native_price_usd + native_price_unit. Omit entirely if no price is stated.",
                      properties: {
                        input:             { type: "number" },
                        output:            { type: "number" },
                        context_window:    { type: "integer" },
                        pricing_model:     { type: "string" },
                        price_summary:     { type: "string" },
                        native_price_usd:  { type: "number" },
                        native_price_unit: { type: "string" }
                      } },
      notes:        { type: "string", description: "One-sentence note on what was found (max 300 chars)." }
    },
    required: %w[name confidence]
  }.freeze

  TOOL_DEFINITION = {
    name:        "extract_models",
    description: "Extract every new AI model announced by a news item, for a pricing directory.",
    input_schema: {
      type: "object",
      properties: {
        models: { type: "array", items: MODEL_SCHEMA,
                  description: "One entry per NEW, named AI model announced (not a feature, price change, or general news). Empty if none." }
      },
      required: %w[models]
    }
  }.freeze

  SYSTEM_PROMPT = <<~PROMPT.strip
    You extract newly-announced AI models for tokenprice.fyi, an API pricing directory.
    Given a news headline, its source, and (when available) an excerpt of the linked
    article, list every NEW, named model the item announces (not a feature update, price
    change, funding round, or general commentary). Some sources are daily roundups
    covering several unrelated stories in one item — read the whole excerpt, not just the
    headline, since a second or third model launch can be mentioned in passing partway
    through rather than in the lead story. For each model, extract its name, provider, and
    pricing family. Include the price ONLY if the item states it — never guess a number;
    omit pricing and lower confidence instead. A real launch with no stated price is still
    worth extracting (identity only). Return an empty list if nothing qualifies.
  PROMPT

  # Sized for several models per call, not one — a digest bundling 3-4 launches
  # each needs a full MODEL_SCHEMA object (name, provider, category, a nested
  # pricing object, notes); 1536 was sized for the old single-object response
  # and would risk truncating mid-JSON on exactly the multi-model case this
  # array schema exists to handle.
  MAX_TOKENS = 4096

  def initialize(news_item, client: nil)
    @news_item = news_item
    @client    = client
  end

  def run
    content = "Headline: #{news_item.title}\nSource: #{news_item.source}\n" \
              "URL: #{news_item.url}#{news_item.excerpt_section}"

    input = AnthropicClient.tool_call(
      model:      MODEL,
      system:     SYSTEM_PROMPT,
      messages:   [ { role: "user", content: content } ],
      tool:       TOOL_DEFINITION,
      max_tokens: MAX_TOKENS,
      client:     @client
    )

    Array(input[:models]).filter_map { |model| build_candidate(model) }
  rescue AnthropicClient::Error => e
    raise Error, e.message
  end

  private

  attr_reader :news_item

  def build_candidate(model)
    name = model[:name].to_s.strip
    return nil if name.blank?

    ModelCandidate.new(
      news_item:     news_item,
      name:          name,
      provider_name: model[:provider].to_s.strip.presence || news_item.source,
      category_slug: normalize_category(model[:category]),
      pricing:       model[:pricing].presence,
      released_on:   parse_date(model[:released_on]),
      source_url:    news_item.url,
      confidence:    normalize_confidence(model[:confidence]),
      rationale:     model[:notes].to_s.truncate(300),
      status:        "pending"
    )
  end

  def normalize_category(value)
    CATEGORY_SLUGS.include?(value) ? value : nil
  end

  def normalize_confidence(value)
    %w[H M L].include?(value) ? value : "L"
  end

  def parse_date(value)
    Date.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
