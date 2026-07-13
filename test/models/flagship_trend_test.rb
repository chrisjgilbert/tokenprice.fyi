require "test_helper"

class FlagshipTrendTest < ActiveSupport::TestCase
  test "builds one trend per provider from priced frontier models, richest first" do
    trends = FlagshipTrend.all

    # Anthropic (opus + suspended fable, both frontier & priced) leads DeepSeek
    # (one frontier model) because trends sort by history length.
    assert_equal %w[Anthropic DeepSeek], trends.map(&:provider_name)
    assert_equal [ 2, 1 ], trends.map { |t| t.steps.size }
    assert trends.first.accent.present?
  end

  test "steps are chronological and carry the launch price, not later cuts" do
    deepseek = FlagshipTrend.all.find { |t| t.provider_slug == "deepseek" }

    # deepseek-v4-pro launched at 1.74 and was later cut to 0.435; the flagship
    # line anchors on the launch price, so the cut must not leak in.
    assert_equal 1, deepseek.steps.size
    assert_in_delta 1.74, deepseek.steps.first.input, 0.001
  end

  test "input_range and output_range span a provider's flagship launch prices" do
    anthropic = FlagshipTrend.all.find { |t| t.provider_slug == "anthropic" }

    # opus $5 in / $25 out (May 2026), fable $10 in / $50 out (Jun 2026).
    assert_equal [ 5.0, 10.0 ],  anthropic.input_range
    assert_equal [ 25.0, 50.0 ], anthropic.output_range
  end

  test "output_range is nil when no flagship has an output rate" do
    trend = FlagshipTrend.new(provider_name: "X", provider_slug: "x", accent: "#000",
      steps: [ FlagshipTrend::Step.new(date: Date.new(2025, 1, 1), model_name: "m",
                                       model_slug: "m", input: 5.0, output: nil) ])

    assert_equal [ 5.0, 5.0 ], trend.input_range
    assert_nil trend.output_range
  end

  test "input_as_of returns the flagship in effect on a date, nil before launch" do
    anthropic = FlagshipTrend.all.find { |t| t.provider_slug == "anthropic" }

    assert_nil anthropic.input_as_of(Date.new(2026, 1, 1))          # before opus
    assert_in_delta 5.0,  anthropic.input_as_of(Date.new(2026, 5, 29)), 0.001 # opus reigns
    assert_in_delta 10.0, anthropic.input_as_of(Date.current), 0.001         # fable now
  end

  test "floor_series steps down to the cheapest available frontier input over time" do
    series = FlagshipTrend.floor_series(FlagshipTrend.all)

    # Fixtures: deepseek $1.74 (Feb 2026) then anthropic opus $5 (May) + fable $10.
    # The floor is the cheapest in effect at each date, so it opens at 1.74 and
    # never rises above it.
    assert_equal series.map(&:date), series.map(&:date).sort
    assert_in_delta 1.74, series.first.input, 0.001
    assert_operator series.map(&:input).max, :<=, 1.74 + 0.001
  end

  test "excludes a frontier model whose launch input price is zero" do
    provider = Provider.create!(name: "Free Labs", slug: "free-labs", accent: "#222222")
    model = provider.ai_models.create!(name: "Free Frontier", tier: "frontier",
                                       status: "active", released_on: Date.new(2025, 1, 1),
                                       source: AiModel::MANUAL_SOURCE)
    model.price_points.create!(effective_on: Date.new(2025, 1, 1), input_per_mtok: 0, output_per_mtok: 0)

    # A $0 launch price can't anchor a log-axis step and isn't a real flagship
    # rate; the provider must not produce a trend.
    assert_nil FlagshipTrend.all.find { |t| t.provider_slug == "free-labs" }
  end

  test "last_modified reflects a frontier-model metadata edit that touches no price row" do
    before = FlagshipTrend.last_modified
    ai_models(:opus).update!(released_on: ai_models(:opus).released_on - 1.day)

    assert_operator FlagshipTrend.last_modified, :>, before
  end

  test "last_modified reflects a provider edit — the chart renders provider names and accents" do
    before = FlagshipTrend.last_modified
    providers(:anthropic).update!(accent: "#123123")

    assert_operator FlagshipTrend.last_modified, :>, before
  end

  test "includes superseded flagships that the public catalog hides" do
    provider = Provider.create!(name: "Historic Labs", slug: "historic-labs", accent: "#123456")
    model = provider.ai_models.create!(name: "Historic Frontier One", tier: "frontier",
                                       status: "retired", released_on: Date.new(2024, 1, 1),
                                       source: AiModel::MANUAL_SOURCE)
    model.price_points.create!(effective_on: Date.new(2024, 1, 1), input_per_mtok: 40, output_per_mtok: 80)

    trend = FlagshipTrend.all.find { |t| t.provider_slug == "historic-labs" }

    # Retired, so it never appears in PriceCatalog.models — but a retired model is
    # a *former* flagship, exactly what the timeline exists to surface.
    refute_includes PriceCatalog.models.map(&:slug), "historic-frontier-one"
    assert trend, "expected a trend for the retired-only provider"
    assert_in_delta 40, trend.current.input, 0.001
  end
end
