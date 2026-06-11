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

  test "price_as_of returns the snapshot in effect on a date" do
    ds = ai_models(:deepseek_v4)
    # deepseek_launch is 2026-02-01, deepseek_cut is 2026-05-31.
    assert_nil ds.price_as_of(Date.new(2026, 1, 1))
    assert_equal price_points(:deepseek_launch), ds.price_as_of(Date.new(2026, 2, 1))
    assert_equal price_points(:deepseek_launch), ds.price_as_of(Date.new(2026, 5, 30))
    assert_equal price_points(:deepseek_cut),    ds.price_as_of(Date.new(2026, 6, 1))
  end

  test "blended_change_over since launch matches blended_change_since_launch" do
    ds = ai_models(:deepseek_v4)
    assert_in_delta(-75.0, ds.blended_change_over(:launch), 0.1)
    assert_in_delta ds.blended_change_since_launch, ds.blended_change_over(:launch), 0.0001
  end

  test "blended_change_over trailing window captures a move within it" do
    travel_to Date.new(2026, 6, 11) do
      ds = ai_models(:deepseek_v4)
      # The 75% cut (2026-05-31) falls inside all of these windows.
      assert_in_delta(-75.0, ds.blended_change_over(30.days), 0.1)
      assert_in_delta(-75.0, ds.blended_change_over(90.days), 0.1)
      assert_in_delta(-75.0, ds.blended_change_over(1.year), 0.1)
    end
  end

  test "blended_change_over is nil when the price is flat across the window" do
    travel_to Date.new(2026, 6, 11) do
      # A window starting after the cut sees only the post-cut price — no move.
      assert_nil ai_models(:deepseek_v4).blended_change_over(2.days)
      # Single-snapshot model never has a move to report.
      assert_nil ai_models(:opus).blended_change_over(30.days)
    end
  end

  test "blended_changes returns a percentage for every window in order" do
    travel_to Date.new(2026, 6, 11) do
      labels = ai_models(:deepseek_v4).blended_changes.map(&:first)
      assert_equal [ "30d", "90d", "1y", "Since launch" ], labels
      assert ai_models(:deepseek_v4).blended_changes.all? { |_, pct| pct.present? }
    end
  end

  test "slug is auto-generated from name on create" do
    model = ai_models(:opus).provider.ai_models.create!(name: "Claude Test 9", tier: "mid")
    assert_equal "claude-test-9", model.slug
  end

  test "tier and status reject invalid values" do
    model = AiModel.new(provider: providers(:anthropic), name: "X", tier: "nope")
    assert_not model.valid?
  end

  test "listed excludes models with no price points" do
    listed = AiModel.listed
    assert_includes listed, ai_models(:opus)
    assert_includes listed, ai_models(:deepseek_v4)
    assert_not_includes listed, ai_models(:no_price)
    assert_not_includes listed, ai_models(:retired_instant)
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

  test "matches? does not subsequence-match across word boundaries" do
    # Each is an in-order letter pick from "claudeopus48" but no single word.
    %w[cap lap cs4 la8].each do |junk|
      assert_not ai_models(:opus).matches?(junk), "#{junk.inspect} should not match Claude Opus 4.8"
    end
    # Within a single word a dropped letter still matches ("opus" sans u).
    assert ai_models(:opus).matches?("ops")
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
