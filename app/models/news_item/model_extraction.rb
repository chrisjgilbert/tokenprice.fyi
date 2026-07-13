# Extracts a ModelCandidate from a "release"-classified NewsItem using Claude —
# the detection→curation bridge's read step. Reached through
# NewsItem#extract_model_candidate; returns an unsaved ModelCandidate, or nil when
# the item doesn't actually announce an identifiable new model. Dedup against the
# existing catalog is the job's concern, not this operation's.
#
# Pricing is best-effort and confidence-rated: the extractor is told to return the
# price ONLY when the headline/source makes it evident, and to omit it (leaving the
# reviewer to price from source_url) rather than guess — the same "never publish an
# unconfirmed number" rule the pricing docs hold. A launch with no stated price
# still yields a candidate (identity + confidence "L"), so nothing slips by.
class NewsItem::ModelExtraction
  class Error < StandardError; end

  MODEL = "claude-haiku-4-5-20251001"

  CATEGORY_SLUGS = ModelCategory.all.map(&:slug).freeze

  TOOL_DEFINITION = {
    name:        "extract_model",
    description: "Extract a new AI model announced by a news item, for a pricing directory.",
    input_schema: {
      type: "object",
      properties: {
        is_new_model: { type: "boolean",
                        description: "True only if the item announces a NEW, named AI model (not a feature, price change, or general news)." },
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
      required: %w[is_new_model confidence]
    }
  }.freeze

  SYSTEM_PROMPT = <<~PROMPT.strip
    You extract newly-announced AI models for tokenprice.fyi, an API pricing directory.
    Given a news headline and its source, decide whether it announces a NEW, named model
    (not a feature update, price change, funding round, or general commentary). If it does,
    extract the model's name, provider, and pricing family. Include the price ONLY if the
    item states it — never guess a number; omit pricing and lower confidence instead. A real
    launch with no stated price is still a model worth extracting (identity only).
  PROMPT

  def initialize(news_item, client: nil)
    @news_item = news_item
    @client    = client
  end

  def run
    content = "Headline: #{news_item.title}\nSource: #{news_item.source}\nURL: #{news_item.url}"

    input = AnthropicClient.tool_call(
      model:      MODEL,
      system:     SYSTEM_PROMPT,
      messages:   [ { role: "user", content: content } ],
      tool:       TOOL_DEFINITION,
      max_tokens: 512,
      client:     @client
    )

    return nil unless input[:is_new_model] && input[:name].to_s.strip.present?

    ModelCandidate.new(
      news_item:     news_item,
      name:          input[:name].to_s.strip,
      provider_name: input[:provider].to_s.strip.presence || news_item.source,
      category_slug: normalize_category(input[:category]),
      pricing:       input[:pricing].presence,
      released_on:   parse_date(input[:released_on]),
      source_url:    news_item.url,
      confidence:    normalize_confidence(input[:confidence]),
      rationale:     input[:notes].to_s.truncate(300),
      status:        "pending"
    )
  rescue AnthropicClient::Error => e
    raise Error, e.message
  end

  private

  attr_reader :news_item

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
