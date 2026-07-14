require "test_helper"

class AiModel::DescribableTest < ActiveSupport::TestCase
  def model
    @model ||= ai_models(:opus)
  end

  # A listed (priced) OpenRouter row on the given provider.
  def listed_model(provider, **attrs)
    m = provider.ai_models.create!({
      source: AiModel::OPENROUTER_SOURCE, status: "active", description: "d"
    }.merge(attrs))
    m.price_points.create!(effective_on: Date.current, input_per_mtok: 1,
                           output_per_mtok: 1, source: "test")
    m
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

  test "sibling_lineup covers the provider's other listed models, newest first" do
    names = model.sibling_lineup.map(&:name)

    assert_not_includes names, model.name,          "excludes itself"
    assert_not_includes names, "Claude Instant 1",  "excludes retired siblings"
    assert_not_includes names, "Claude No Price",   "excludes unlisted (price-less) siblings"
    assert_includes names, "Guide Haiku Fixture"

    dated = model.sibling_lineup.map(&:released_on).compact
    assert_equal dated.sort.reverse, dated, "ordered newest first"
  end

  test "sibling_lineup respects the limit" do
    assert_operator model.sibling_lineup(limit: 1).size, :<=, 1
  end

  # For a provider with more models than the cap, the lineup is the target's
  # release-neighbours — not the globally newest rows, which may be a different
  # tier — so an older model is positioned against its own cohort and successors.
  test "sibling_lineup for a large provider picks release-neighbours, not just the newest" do
    provider = Provider.create!(name: "BigLab", slug: "biglab-#{SecureRandom.hex(3)}")
    target = listed_model(provider, name: "Mid", released_on: Date.new(2025, 1, 1))
    listed_model(provider, name: "Far New A", released_on: Date.new(2026, 1, 1))
    listed_model(provider, name: "Far New B", released_on: Date.new(2026, 2, 1))
    listed_model(provider, name: "Near Older", released_on: Date.new(2024, 12, 1))
    listed_model(provider, name: "Near Newer", released_on: Date.new(2025, 2, 1))

    names = target.sibling_lineup(limit: 2).map(&:name)

    assert_equal [ "Near Newer", "Near Older" ], names,
                 "nearest two by release, newest presented first"
  end

  test "sibling_lineup falls back to newest when the target has no release date" do
    provider = Provider.create!(name: "DatelessLab", slug: "dateless-#{SecureRandom.hex(3)}")
    target = listed_model(provider, name: "Undated", released_on: nil)
    listed_model(provider, name: "Oldest", released_on: Date.new(2024, 1, 1))
    listed_model(provider, name: "Newest", released_on: Date.new(2026, 1, 1))

    assert_equal [ "Newest" ], target.sibling_lineup(limit: 1).map(&:name)
  end

  test "generate_description feeds the provider lineup to the generator" do
    captured = {}
    fake = fake_anthropic_tool_client(
      input: { description: "D.", strengths: "S.", best_for: "B.", limitations: "L." },
      into:  captured
    )

    model.generate_description(client: fake)

    content = captured[:messages].first[:content]
    assert_includes content, "Provider lineup"
    assert_includes content, "Guide Haiku Fixture"
  end

  # The headline behaviour: a launch flags a sibling stale, and the refresh must
  # actually see the newer model so it can reposition against it.
  test "refresh_description feeds a newer sibling into the prompt" do
    newer = model.provider.ai_models.create!(
      source: AiModel::OPENROUTER_SOURCE, name: "Claude Nova 9", status: "active",
      released_on: Date.current, description: "The newest frontier model."
    )
    newer.price_points.create!(effective_on: Date.current, input_per_mtok: 1,
                               output_per_mtok: 1, source: "test")
    model.update!(strengths: "S.", description_generated_at: 100.days.ago)
    captured = {}
    fake = fake_anthropic_tool_client(
      input: { description: "D.", strengths: "S.", best_for: "B.", limitations: "L." },
      into:  captured
    )

    model.refresh_description(client: fake)

    assert_includes captured[:messages].first[:content], "Claude Nova 9"
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
