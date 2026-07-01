# Generates the "so what" for a launch — one or two sentences on why the model
# matters for someone pricing or choosing an LLM API — using Claude Sonnet 5.
# Reached through AiModel#generate_insight; returns { so_what: } or raises Error.
#
# Unlike MarketEvent::Insight this doesn't web-search: a launch's price, tier,
# and context window already live on the record, so a plain forced tool-call
# (mirroring AiModel::Description) is enough grounding, and it keeps launch
# cards free of external citation links.
class AiModel::Insight
  class Error < StandardError; end

  MODEL = "claude-sonnet-5"

  TOOL_DEFINITION = {
    name:        "write_launch_so_what",
    description: "Record why a new LLM API model release matters for someone pricing or choosing an API.",
    input_schema: {
      type:       "object",
      properties: {
        so_what: { type: "string", description: "One or two sentences on why the release matters." }
      },
      required: %w[so_what]
    }
  }.freeze

  SYSTEM_PROMPT = <<~PROMPT.strip
    You write the "so what" for launch entries on tokenprice.fyi, a site that tracks LLM API token
    prices. Given a newly released model with its price, tier, and context window, write one or two
    sentences on why it matters for someone pricing or choosing an LLM API — the implication a reader
    would otherwise have to work out for themselves.

    Voice: a developer who tracks this market explaining it to a peer. Describe the implication; don't
    tell the reader what their own situation is. Prefer a concrete figure over a mood. No rhetorical
    questions, no "X is Y" fragments, no hype words. State the consequence plainly.

    Write only the one or two sentences — no preamble, no heading, no "So what:" label.
  PROMPT

  def initialize(model, client: nil)
    @model  = model
    @client = client
  end

  def run
    input = AnthropicClient.tool_call(
      model:      MODEL,
      system:     SYSTEM_PROMPT,
      messages:   [ { role: "user", content: prompt } ],
      tool:       TOOL_DEFINITION,
      max_tokens: 512,
      client:     @client
    )

    { so_what: SoWhat.clamp(input[:so_what]) }
  rescue AnthropicClient::Error => e
    raise Error, e.message
  end

  private

  attr_reader :model

  def prompt
    lines = [ "Model: #{model.name}", "Provider: #{model.provider.name}", "Tier: #{model.tier}" ]
    lines << "Price: $#{model.current_input} in / $#{model.current_output} out per 1M tokens" if model.current_price
    lines << "Context window: #{model.context_window} tokens" if model.context_window
    lines << "Description: #{model.description}" if model.description.present?
    lines.join("\n")
  end
end
