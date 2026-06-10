require "test_helper"

class PricePointTest < ActiveSupport::TestCase
  test "fixture is valid" do
    assert price_points(:opus_launch).valid?
  end

  test "requires input and output prices" do
    pp = PricePoint.new(ai_model: ai_models(:opus), effective_on: Date.new(2026, 7, 1))
    assert_not pp.valid?
    assert pp.errors[:input_per_mtok].any?
    assert pp.errors[:output_per_mtok].any?
  end

  test "rejects negative prices" do
    pp = PricePoint.new(ai_model: ai_models(:opus), effective_on: Date.new(2026, 7, 1),
                        input_per_mtok: -1, output_per_mtok: 1)
    assert_not pp.valid?
    assert pp.errors[:input_per_mtok].any?
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
