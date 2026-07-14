# Classifies a persisted NewsItem as relevant to LLM token pricing using Claude Haiku.
# Reached through NewsItem#classify; returns { relevant:, kind:, rationale: } or
# raises Error on API failure.
class NewsItem::Classification
  class Error < StandardError; end

  MODEL = "claude-haiku-4-5-20251001"

  TOOL_DEFINITION = {
    name:        "classify_headline",
    description: "Classify whether a news headline is relevant to LLM API pricing.",
    input_schema: {
      type:       "object",
      properties: {
        relevant:  { type: "boolean",
                     description: "True if relevant to LLM token pricing (releases, price changes, market events)." },
        kind:      { type: "string", enum: %w[release price market other],
                     description: "release=new model, price=pricing change, market=broader market event, other=not relevant." },
        rationale: { type: "string",
                     description: "One-sentence explanation of the classification (max 200 chars)." }
      },
      required: %w[relevant kind rationale]
    }
  }.freeze

  SYSTEM_PROMPT = <<~PROMPT.strip
    You are a relevance classifier for an LLM token pricing tracker (tokenprice.fyi).
    Given a news headline, its source, and (when available) an excerpt of the linked
    article, determine if the story is relevant to LLM API pricing: model releases,
    price changes, or significant market events affecting LLM API costs.
    Some sources are daily roundups covering several unrelated stories in one item —
    judge relevance on the excerpt as a whole, not just the headline: a roundup whose
    title covers one story can still contain a release, price change, or market event
    buried further in the excerpt.
    Be concise in rationale (one sentence).
  PROMPT

  def initialize(news_item, client: nil)
    @news_item = news_item
    @client    = client
  end

  def run
    content = "Headline: #{news_item.title}\nSource: #{news_item.source}#{news_item.excerpt_section}"

    input = AnthropicClient.tool_call(
      model:      MODEL,
      system:     SYSTEM_PROMPT,
      messages:   [ { role: "user", content: content } ],
      tool:       TOOL_DEFINITION,
      max_tokens: 256,
      client:     @client
    )

    {
      relevant:  input[:relevant],
      kind:      input[:kind],
      rationale: input[:rationale].to_s.truncate(200)
    }
  rescue AnthropicClient::Error => e
    raise Error, e.message
  end

  private

  attr_reader :news_item
end
