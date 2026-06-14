require "anthropic"

# Classifies a news headline as relevant to LLM token pricing using Claude Haiku.
# Returns { relevant:, kind:, rationale: } or raises ClassifyError on API failure.
#
#   NewsClassifier.classify(title: "OpenAI cuts GPT-4o prices 50%", source: "openai")
#   #=> { relevant: true, kind: "price", rationale: "Direct LLM API price cut announcement" }
class NewsClassifier
  class ClassifyError < StandardError; end

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
    Given a news headline and its source, determine if the story is relevant to LLM API pricing:
    model releases, price changes, or significant market events affecting LLM API costs.
    Be concise in rationale (one sentence).
  PROMPT

  def self.classify(title:, source:, body: nil)
    new.classify(title: title, source: source, body: body)
  end

  def classify(title:, source:, body: nil)
    content = "Headline: #{title}\nSource: #{source}"
    content += "\n\nContext: #{body.first(500)}" if body.present?

    response = client.messages.create(
      model:       MODEL,
      max_tokens:  256,
      system_:     SYSTEM_PROMPT,
      messages:    [ { role: "user", content: content } ],
      tools:       [ TOOL_DEFINITION ],
      tool_choice: { type: "tool", name: "classify_headline" }
    )

    tool_use = response.content.find { |block| block.type == :tool_use }
    raise ClassifyError, "No tool_use block in response" unless tool_use

    input = tool_use.input
    {
      relevant:  input[:relevant],
      kind:      input[:kind],
      rationale: input[:rationale].to_s.truncate(200)
    }
  rescue Anthropic::Errors::Error => e
    raise ClassifyError, "Anthropic API error: #{e.message}"
  end

  private

  def client
    @client ||= AnthropicClient.build
  end
end
