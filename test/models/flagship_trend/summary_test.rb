require "test_helper"

class FlagshipTrend::SummaryTest < ActiveSupport::TestCase
  test "floor_drop tracks the cheapest frontier input from the first flagship to the lowest" do
    summary = FlagshipTrend::Summary.new([
      trend("First", steps: [ step("2023-03-01", 30) ]),
      trend("Cheap", steps: [ step("2025-04-01", 0.15) ]),
      trend("Mid",   steps: [ step("2024-03-01", 15) ])
    ])

    drop = summary.floor_drop
    assert_equal "2023-03-01", drop[:from].date.to_s
    assert_in_delta 30,   drop[:from].input, 0.001
    assert_in_delta 0.15, drop[:to].input, 0.001
    assert_equal 200, drop[:multiple]
  end

  test "floor_drop is nil for a single flagship or a sub-2x fall" do
    assert_nil FlagshipTrend::Summary.new([
      trend("Solo", steps: [ step("2023-01-01", 30) ])
    ]).floor_drop

    # $1.30 → $1.00 rounds to 1× — not worth a "cheaper" claim.
    assert_nil FlagshipTrend::Summary.new([
      trend("Dear",  steps: [ step("2023-01-01", 1.30) ]),
      trend("Close", steps: [ step("2024-01-01", 1.00) ])
    ]).floor_drop
  end

  test "floor_drop's `from` is deterministic on an earliest-date tie — the dearest wins" do
    summary = FlagshipTrend::Summary.new([
      trend("Cheap", steps: [ step("2023-03-14", 30) ]),
      trend("Dear",  steps: [ step("2023-03-14", 60) ]),
      trend("Later", steps: [ step("2025-01-01", 0.6) ])
    ])

    assert_in_delta 60, summary.floor_drop[:from].input, 0.001
    assert_equal 100, summary.floor_drop[:multiple]
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

  test "price_span is nil when the spread rounds below 2×" do
    summary = FlagshipTrend::Summary.new([
      trend("Near",  steps: [ step("2025-01-01", 2) ]),
      trend("Close", steps: [ step("2025-01-01", 2.5) ])
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
