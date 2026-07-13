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

  test "generate_description stamps description_generated_at" do
    assert_nil model.description_generated_at
    fake = fake_anthropic_tool_client(input: {
      description: "D.", strengths: "S.", best_for: "B.", limitations: "L."
    })

    freeze_time do
      model.generate_description(client: fake)
      assert_equal Time.current, model.reload.description_generated_at
    end
  end

  test "refresh_description regenerates the copy and restamps" do
    model.update!(description: "Old.", strengths: "Old S.", best_for: "Old B.",
                  limitations: "Old L.", description_generated_at: 100.days.ago)
    fake = fake_anthropic_tool_client(input: {
      description: "Fresh.", strengths: "Fresh S.", best_for: "Fresh B.", limitations: "Fresh L."
    })

    freeze_time do
      model.refresh_description(client: fake)
      model.reload

      assert_equal "Fresh.",   model.description
      assert_equal "Fresh S.", model.strengths
      assert_equal Time.current, model.description_generated_at
    end
  end

  # A refresh never sends the stale description back as source_text — it
  # regenerates from Claude's current knowledge rather than paraphrasing the copy
  # it's replacing.
  test "refresh_description does not feed the old description back to the generator" do
    model.update!(description: "Old blurb.", strengths: "S.")
    captured = {}
    fake = fake_anthropic_tool_client(
      input: { description: "D.", strengths: "S.", best_for: "B.", limitations: "L." },
      into:  captured
    )

    model.refresh_description(client: fake)

    refute_includes captured[:messages].first[:content], "Old blurb."
  end

  # A thin regeneration (any blank facet) must not blank out good existing copy.
  # The row keeps its write-up and only its timestamp advances, so it waits a
  # full window before we try again instead of re-attempting every run.
  test "refresh_description keeps existing copy when the regeneration is incomplete" do
    model.update!(description: "Kept.", strengths: "Kept S.", best_for: "Kept B.",
                  limitations: "Kept L.", description_generated_at: 100.days.ago)
    fake = fake_anthropic_tool_client(input: {
      description: "New.", strengths: "New S.", best_for: "", limitations: "New L."
    })

    freeze_time do
      model.refresh_description(client: fake)
      model.reload

      assert_equal "Kept.",   model.description
      assert_equal "Kept S.", model.strengths
      assert_equal "Kept B.", model.best_for
      assert_equal Time.current, model.description_generated_at,
                   "timestamp advances so the un-describable row waits a full window before retry"
    end
  end
end
