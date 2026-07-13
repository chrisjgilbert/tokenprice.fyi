require "test_helper"

class AiModel::DescribableTest < ActiveSupport::TestCase
  def model
    @model ||= ai_models(:opus)
  end

  test "generates and persists the four editorial columns" do
    fake = fake_anthropic_tool_client(input: {
      description: "A frontier reasoning model from Anthropic.",
      strengths:   "Strong at multi-step reasoning and long-context work.",
      best_for:    "Hard analytical tasks where accuracy beats latency.",
      limitations: "Slower than mid-tier models on simple prompts."
    })

    model.generate_description(client: fake)
    model.reload

    assert_equal "A frontier reasoning model from Anthropic.", model.description
    assert_equal "Strong at multi-step reasoning and long-context work.", model.strengths
    assert_equal "Hard analytical tasks where accuracy beats latency.", model.best_for
    assert_equal "Slower than mid-tier models on simple prompts.", model.limitations
  end

  # The clamp turns an empty facet into nil; the facade must not blank out an
  # existing description in that case.
  test "keeps the existing description when the generator returns a blank one" do
    model.update!(description: "Existing blurb.")
    fake = fake_anthropic_tool_client(input: {
      description: "", strengths: "S", best_for: "B", limitations: "L"
    })

    model.generate_description(client: fake)

    assert_equal "Existing blurb.", model.reload.description
  end
end
