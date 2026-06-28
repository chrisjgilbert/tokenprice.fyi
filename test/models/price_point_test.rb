require "test_helper"

class PricePointTest < ActiveSupport::TestCase
  test "fixture is valid" do
    assert price_points(:opus_launch).valid?
  end

  test "a native-price-only point with NULL text rates is valid" do
    pp = PricePoint.new(ai_model: ai_models(:priced_image_gen), effective_on: Date.new(2026, 7, 1),
                        native_price_usd: 0.04)
    assert pp.valid?, pp.errors.full_messages.to_sentence
  end

  test "a text-rates-only point is valid (regression)" do
    pp = PricePoint.new(ai_model: ai_models(:opus), effective_on: Date.new(2026, 7, 1),
                        input_per_mtok: 5, output_per_mtok: 25)
    assert pp.valid?, pp.errors.full_messages.to_sentence
  end

  test "a point that prices nothing is invalid" do
    pp = PricePoint.new(ai_model: ai_models(:opus), effective_on: Date.new(2026, 7, 1))
    assert_not pp.valid?
    assert pp.errors[:base].any?
  end

  test "input without output is invalid (text rates are present-together)" do
    pp = PricePoint.new(ai_model: ai_models(:opus), effective_on: Date.new(2026, 7, 1),
                        input_per_mtok: 5)
    assert_not pp.valid?
    assert pp.errors[:base].any?
  end

  test "output without input is invalid (text rates are present-together)" do
    pp = PricePoint.new(ai_model: ai_models(:opus), effective_on: Date.new(2026, 7, 1),
                        output_per_mtok: 25)
    assert_not pp.valid?
    assert pp.errors[:base].any?
  end

  test "rejects negative prices" do
    pp = PricePoint.new(ai_model: ai_models(:opus), effective_on: Date.new(2026, 7, 1),
                        input_per_mtok: -1, output_per_mtok: 1)
    assert_not pp.valid?
    assert pp.errors[:input_per_mtok].any?
  end

  test "rejects a negative native price" do
    pp = PricePoint.new(ai_model: ai_models(:priced_image_gen), effective_on: Date.new(2026, 7, 1),
                        native_price_usd: -1)
    assert_not pp.valid?
    assert pp.errors[:native_price_usd].any?
  end

  test "effective_on must be unique per model" do
    dup = PricePoint.new(ai_model: ai_models(:opus),
                         effective_on: price_points(:opus_launch).effective_on,
                         input_per_mtok: 1, output_per_mtok: 1)
    assert_not dup.valid?
    assert dup.errors[:effective_on].any?
  end

  test "the same date is allowed for a different model" do
    pp = PricePoint.new(ai_model: ai_models(:deepseek_v4),
                        effective_on: price_points(:opus_launch).effective_on,
                        input_per_mtok: 1, output_per_mtok: 1)
    assert pp.valid?
  end
end
