require "test_helper"

class AiModelTest < ActiveSupport::TestCase
  test "current_price is the most recent snapshot" do
    assert_equal price_points(:deepseek_cut), ai_models(:deepseek_v4).current_price
  end

  test "launch_price is the earliest snapshot" do
    assert_equal price_points(:deepseek_launch), ai_models(:deepseek_v4).launch_price
  end

  test "blended price uses the 3:1 input:output weighting" do
    # Opus: (5*3 + 25) / 4 = 10
    assert_in_delta 10.0, ai_models(:opus).blended_per_mtok, 0.0001
  end

  test "blended_change_since_launch reflects the DeepSeek 75% cut" do
    assert_in_delta(-75.0, ai_models(:deepseek_v4).blended_change_since_launch, 0.1)
  end

  test "single-snapshot model reports no change" do
    assert_nil ai_models(:opus).blended_change_since_launch
    assert_not ai_models(:opus).price_changed?
  end

  test "slug is auto-generated from name on create" do
    model = ai_models(:opus).provider.ai_models.create!(name: "Claude Test 9", tier: "mid")
    assert_equal "claude-test-9", model.slug
  end

  test "tier and status reject invalid values" do
    model = AiModel.new(provider: providers(:anthropic), name: "X", tier: "nope")
    assert_not model.valid?
  end

  test "matches? finds substrings of name, provider and slug" do
    model = ai_models(:opus)
    assert model.matches?("opus")
    assert model.matches?("Anthropic")
    assert model.matches?("claude-opus")
  end

  test "matches? forgives punctuation differences and typos" do
    model = ai_models(:opus)
    assert model.matches?("opus 4.8")
    assert model.matches?("opus48")
    assert model.matches?("antropic"), "subsequence match should forgive a dropped letter"
  end

  test "matches? requires every query word to match" do
    assert_not ai_models(:opus).matches?("opus gemini")
    assert_not ai_models(:opus).matches?("deepseek")
  end

  test "matches? accepts everything for a blank query" do
    assert ai_models(:opus).matches?("")
    assert ai_models(:opus).matches?(nil)
  end

  test "price helpers use the eager-loaded association without extra queries" do
    model = AiModel.includes(:price_points).find(ai_models(:deepseek_v4).id)
    assert_queries_count(0) do
      model.current_price
      model.launch_price
      model.blended_per_mtok
    end
  end
end
