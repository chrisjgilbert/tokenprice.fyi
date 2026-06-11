require "test_helper"

class ModelInsightsTest < ActiveSupport::TestCase
  test "facts include the I/O ratio and cached saving for a priced model" do
    labels = ModelInsights.new(ai_models(:opus)).facts.map(&:label)

    assert labels.any? { |l| l.include?("Output costs 5× input") }, labels.inspect
    assert labels.any? { |l| l.include?("Cached input saves 90%") }, labels.inspect
  end

  test "ranks a model against same-tier peers by blended price" do
    # Fixtures: opus (blended 10) and deepseek_v4 (blended ~0.49 after the cut)
    # are the only two frontier models with prices, so DeepSeek is cheapest.
    labels = ModelInsights.new(ai_models(:deepseek_v4)).facts.map(&:label)
    assert labels.any? { |l| l.include?("Cheapest frontier model") }, labels.inspect

    opus_labels = ModelInsights.new(ai_models(:opus)).facts.map(&:label)
    assert opus_labels.any? { |l| l.include?("2nd-cheapest frontier model") }, opus_labels.inspect
  end

  test "trajectory fact reflects a price cut since launch" do
    labels = ModelInsights.new(ai_models(:deepseek_v4)).facts.map(&:label)
    assert labels.any? { |l| l.match?(/Down 75% since launch/) }, labels.inspect
  end

  test "trajectory fact reports a flat single-snapshot model" do
    labels = ModelInsights.new(ai_models(:opus)).facts.map(&:label)
    assert labels.any? { |l| l.start_with?("Held flat since launch") }, labels.inspect
  end

  test "summary_sentence is a compact rank-plus-trajectory line" do
    sentence = ModelInsights.new(ai_models(:deepseek_v4)).summary_sentence
    assert_match(/Currently the cheapest of \d+ frontier models/, sentence)
    assert_match(/down 75% since launch/, sentence)
  end

  test "produces no facts for a model with no price points" do
    assert_empty ModelInsights.new(ai_models(:no_price)).facts
    assert_nil ModelInsights.new(ai_models(:no_price)).summary_sentence
  end
end
