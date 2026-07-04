require "test_helper"

class FlagshipTrend::SummaryTest < ActiveSupport::TestCase
  test "splits providers into cheaper and dearer by first-to-current change" do
    summary = FlagshipTrend::Summary.new([
      trend("Falls", steps: [ step("2024-01-01", 40), step("2025-01-01", 10) ]),
      trend("Rises", steps: [ step("2024-01-01", 2),  step("2025-01-01", 6) ]),
      trend("Only",  steps: [ step("2024-01-01", 5) ])
    ])

    assert summary.compared?
    assert summary.mixed?
    assert_equal %w[Falls], summary.cheaper.map(&:provider_name)
    assert_equal %w[Rises], summary.pricier.map(&:provider_name)
  end

  test "names the sharpest mover in each direction" do
    summary = FlagshipTrend::Summary.new([
      trend("SmallCut", steps: [ step("2024-01-01", 10), step("2025-01-01", 9) ]),
      trend("BigCut",   steps: [ step("2024-01-01", 10), step("2025-01-01", 1) ]),
      trend("BigRise",  steps: [ step("2024-01-01", 1),  step("2025-01-01", 5) ])
    ])

    assert_equal "BigCut",  summary.biggest_cut.provider_name
    assert_equal "BigRise", summary.biggest_rise.provider_name
  end

  test "not mixed when every multi-flagship provider moved the same way" do
    summary = FlagshipTrend::Summary.new([
      trend("A", steps: [ step("2024-01-01", 10), step("2025-01-01", 4) ]),
      trend("B", steps: [ step("2024-01-01", 20), step("2025-01-01", 5) ])
    ])

    refute summary.mixed?
    assert summary.cheaper.any?
    assert_nil summary.biggest_rise
  end

  test "price_span reports the spread of current flagship prices" do
    summary = FlagshipTrend::Summary.new([
      trend("Cheap", steps: [ step("2025-01-01", 0.15) ]),
      trend("Dear",  steps: [ step("2025-01-01", 30) ])
    ])

    span = summary.price_span
    assert_in_delta 0.15, span[:low], 0.001
    assert_in_delta 30,   span[:high], 0.001
    assert_equal 200, span[:multiple]
  end

  test "price_span is nil without at least two priced flagships" do
    summary = FlagshipTrend::Summary.new([
      trend("Lonely", steps: [ step("2025-01-01", 5) ])
    ])

    assert_nil summary.price_span
  end

  private

  def step(date, input)
    FlagshipTrend::Step.new(date: Date.parse(date), model_name: "m", model_slug: "m",
                            input: input.to_f, output: input.to_f * 2)
  end

  def trend(name, steps:)
    FlagshipTrend.new(provider_name: name, provider_slug: name.downcase,
                      accent: "#000000", steps: steps)
  end
end
