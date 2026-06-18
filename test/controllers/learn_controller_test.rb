require "test_helper"

class LearnControllerTest < ActionDispatch::IntegrationTest
  test "the learn index is a directory with the concept series" do
    get learn_url
    assert_response :success
    assert_select "h1", /Understand what you're paying for/
    assert_select ".led-grid .led-card", minimum: 7   # the full 7-concept series
    assert_select ".led-cta a[href*='/cost']"          # closing estimator CTA
  end

  test "the learn index carries no live-data widget (only a decorative stat)" do
    get learn_url
    # The hard rule: live-data widgets live inside explainers, never on the index.
    assert_select ".led-feat .lw", false
    assert_select ".led-feat-stat"
  end

  test "the feature-costs explainer has a live widget and a prefilled estimator CTA" do
    get learn_feature_costs_url
    assert_response :success
    assert_select "h1", /What drives the cost of common features/
    assert_select ".lw"                                # embedded live-data widget
    assert_select ".hp-cta a[href*='/cost?']"          # CTA pre-filled with a workload
  end

  test "the cost-cutting explainer renders with a live widget and CTA" do
    get learn_cost_cutting_url
    assert_response :success
    assert_select "h1", /Cost-cutting strategies/
    assert_select ".lw"
    assert_select ".hp-cta a[href*='/cost?']"
  end

  test "how-pricing-works gained a live widget and an estimator CTA" do
    get how_pricing_works_url
    assert_response :success
    assert_select ".lw"
    assert_select ".hp-cta a[href*='/cost?']"
  end
end
