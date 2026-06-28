# Generates editorial copy — a one-line description plus strengths / best-for /
# limitations — for a model we only have a raw third-party blurb for. The
# OpenRouter sync uses it to give freshly-imported models the same structured
# write-up as the hand-curated catalogue, instead of the truncated upstream
# description that OpenRouter serves for many models.
#
# It runs during import on *unpersisted* attributes (name / provider /
# context_window / source_text), so it is a class-level operation rather than an
# instance facade on a persisted record. `OpenRouter::ModelSync` injects it as a
# `describer:` collaborator and calls `#generate` on it.
#
# Mirrors NewsItem::Classification: a single cheap Haiku tool-call via
# AnthropicClient.tool_call, returning a plain hash. Raises GenerateError on API
# failure so the caller can fall back rather than persist a half-written record.
#
#   AiModel::Description.generate(
#     name: "Gemini 3.5 Flash", provider: "Google",
#     context_window: 1_000_000, source_text: "Google's fast multimodal model…"
#   )
#   #=> { description:, strengths:, best_for:, limitations: }
class AiModel::Description
  class GenerateError < StandardError; end

  MODEL = "claude-haiku-4-5-20251001"

  # Each facet is a single sentence, so a tight cap is plenty and guards against
  # a runaway response. The editorial columns are plain `text`, so this is
  # belt-and-braces rather than a schema requirement.
  DESCRIPTION_LIMIT = 280
  FACET_LIMIT       = 280

  TOOL_DEFINITION = {
    name:        "write_model_copy",
    description: "Record a short editorial write-up of an LLM API model.",
    input_schema: {
      type:       "object",
      properties: {
        description: { type: "string",
                       description: "One-sentence summary of what the model is. No pricing." },
        strengths:   { type: "string",
                       description: "One sentence on what the model is good at. No pricing." },
        best_for:    { type: "string",
                       description: "One sentence on the workloads it suits best. No pricing." },
        limitations: { type: "string",
                       description: "One sentence on its weaknesses or where not to use it. No pricing." }
      },
      required: %w[description strengths best_for limitations]
    }
  }.freeze

  # Voice mirrors the hand-curated `editorial` block in db/seeds.rb: plain,
  # specific, no marketing, and — crucially — never about price (pricing is
  # computed and shown separately, so a dollar figure baked into copy goes stale).
  SYSTEM_PROMPT = <<~PROMPT.strip
    You write factual, concise editorial copy for a catalogue of LLM API models (tokenprice.fyi).
    For the given model, write four single-sentence fields: a description of what it is, its
    strengths, what it is best for, and its limitations.

    Voice: a developer describing the tool to peers — specific and plain. No marketing language,
    no superlatives ("best", "perfect"), no rhetorical questions. Describe what the model is;
    don't tell the reader what their situation is. Never mention price, cost, or dollars —
    pricing is shown separately and would go stale. If you are unsure of a concrete fact, keep
    the claim general rather than inventing specifics.
  PROMPT

  def self.generate(...) = new.generate(...)

  def generate(name:, provider:, context_window: nil, source_text: nil)
    content = +"Model: #{name}\nProvider: #{provider}"
    content << "\nContext window: #{context_window} tokens" if context_window
    if source_text.present?
      content << "\n\nUpstream description (may be truncated; use only as a hint):\n#{source_text}"
    end

    input = AnthropicClient.tool_call(
      model:      MODEL,
      system:     SYSTEM_PROMPT,
      messages:   [ { role: "user", content: content } ],
      tool:       TOOL_DEFINITION,
      max_tokens: 512,
      client:     @client
    )

    {
      description: clamp(input[:description], DESCRIPTION_LIMIT),
      strengths:   clamp(input[:strengths], FACET_LIMIT),
      best_for:    clamp(input[:best_for], FACET_LIMIT),
      limitations: clamp(input[:limitations], FACET_LIMIT)
    }
  rescue AnthropicClient::Error => e
    raise GenerateError, e.message
  end

  private

  def clamp(value, limit)
    # No ellipsis: a generated line should never *look* truncated, and the
    # backfill's repair scope keys off a trailing ellipsis to spot leftover
    # upstream blurbs — our own output must not trip that.
    value.to_s.strip.truncate(limit, omission: "").rstrip.presence
  end
end
