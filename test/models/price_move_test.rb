require "test_helper"

class PriceMoveTest < ActiveSupport::TestCase
  # AiModel#latest_move ——————————————————————————————————————————————————

  test "latest_move is nil for a model with a single snapshot" do
    assert_nil ai_models(:opus).latest_move
  end

  test "latest_move builds deltas only for the dimensions that changed" do
    # deepseek_v4 has a launch price and a 75% cut — all three dimensions move.
    move = ai_models(:deepseek_v4).latest_move

    assert_not_nil move
    assert_equal Date.new(2026, 5, 31), move.effective_on
    input = move.delta(:input)
    assert_equal(-75.0, input.pct)
    assert_equal 1.74, input.old.to_f
    assert_equal 0.435, input.new.to_f
  end

  test "latest_move is nil when the last two snapshots are identical" do
    model = priced_model_with(
      [ Date.new(2026, 6, 1), { input_per_mtok: 2, output_per_mtok: 8 } ],
      [ Date.new(2026, 6, 2), { input_per_mtok: 2, output_per_mtok: 8 } ]
    )
    assert_nil model.latest_move
  end

  test "latest_move omits an unchanged dimension" do
    model = priced_model_with(
      [ Date.new(2026, 6, 1), { input_per_mtok: 2, output_per_mtok: 8 } ],
      [ Date.new(2026, 6, 2), { input_per_mtok: 2, output_per_mtok: 10 } ]
    )
    move = model.latest_move

    assert_nil move.delta(:input), "input didn't change, so it carries no delta"
    assert_equal 25.0, move.delta(:output).pct
  end

  test "latest_move within window excludes a step older than the window" do
    model = priced_model_with(
      [ Date.current - 100, { input_per_mtok: 1, output_per_mtok: 2 } ],
      [ Date.current - 60,  { input_per_mtok: 2, output_per_mtok: 4 } ]
    )
    assert_nil model.latest_move(within: 30.days)
    assert_not_nil model.latest_move(within: nil)
  end

  test "latest_move within window includes a recent step" do
    model = priced_model_with(
      [ Date.current - 10, { input_per_mtok: 1, output_per_mtok: 2 } ],
      [ Date.current - 1,  { input_per_mtok: 2, output_per_mtok: 4 } ]
    )
    assert_not_nil model.latest_move(within: 30.days)
  end

  # PriceMove#headline ———————————————————————————————————————————————————

  test "headline prefers input when input changed" do
    model = priced_model_with(
      [ Date.new(2026, 6, 1), { input_per_mtok: 1, output_per_mtok: 4 } ],
      [ Date.new(2026, 6, 2), { input_per_mtok: 2, output_per_mtok: 8 } ]
    )
    assert_equal :input, model.latest_move.headline.dimension
  end

  test "headline falls to a changed dimension when input held steady" do
    model = priced_model_with(
      [ Date.new(2026, 6, 1), { input_per_mtok: 2, output_per_mtok: 4 } ],
      [ Date.new(2026, 6, 2), { input_per_mtok: 2, output_per_mtok: 8 } ]
    )
    assert_equal :output, model.latest_move.headline.dimension
  end

  # PriceMove::Delta ——————————————————————————————————————————————————————

  test "delta pct is nil when the base is zero or missing" do
    d = PriceMove::Delta.new(dimension: :cached, old: nil, new: 0.15)
    assert_nil d.pct
  end

  test "delta label is the strip's short column name for each dimension" do
    assert_equal "in",     PriceMove::Delta.new(dimension: :input,  old: 1, new: 2).label
    assert_equal "out",    PriceMove::Delta.new(dimension: :output, old: 1, new: 2).label
    assert_equal "cached", PriceMove::Delta.new(dimension: :cached, old: 1, new: 2).label
  end

  private

  def priced_model_with(*points)
    provider = Provider.create!(name: "Move Labs #{SecureRandom.hex(3)}",
                                slug: "move-labs-#{SecureRandom.hex(3)}", accent: "#123456")
    model = provider.ai_models.create!(name: "Mover #{SecureRandom.hex(3)}", tier: "mid",
                                       source: AiModel::MANUAL_SOURCE)
    points.each { |date, attrs| model.price_points.create!(effective_on: date, **attrs) }
    model
  end
end
