require "test_helper"

class LearnControllerTest < ActionDispatch::IntegrationTest
  test "the learn index is a directory with the concept series" do
    get learn_url
    assert_response :success
    assert_select "h1", /Understand what you're paying for/
    assert_select ".led-grid .led-card", minimum: 7   # the full 7-concept series
    # The standalone /cost estimator was removed; the closing estimator CTA with it.
    assert_select ".led-cta", false
  end

  test "the learn index carries no live-data widget (only a decorative stat)" do
    get learn_url
    # The hard rule: live-data widgets live inside explainers, never on the index.
    assert_select ".led-feat .lw", false
    assert_select ".led-feat-stat"
  end

  test "the feature-costs explainer has a live widget and no dead estimator CTA" do
    get learn_feature_costs_url
    assert_response :success
    assert_select "h1", /What drives the cost of common features/
    assert_select ".lw"                                # embedded live-data widget
    # The /cost estimator was removed; its CTA is gone, the ghost cross-link stays.
    assert_no_dead_cost_cta
    assert_select ".hp-cta a"
  end

  test "the cost-cutting explainer renders with a live widget and no dead estimator CTA" do
    get learn_cost_cutting_url
    assert_response :success
    assert_select "h1", /Cost-cutting strategies/
    assert_select ".lw"
    assert_no_dead_cost_cta
    assert_select ".hp-cta a"
  end

  test "how-pricing-works has a live widget and no dead estimator CTA" do
    get how_pricing_works_url
    assert_response :success
    assert_select ".lw"
    assert_no_dead_cost_cta
    assert_select ".hp-cta a"
  end

  private

  # No link points at the removed /cost destination (exact path or with a query
  # string) — anchored so the live /learn/cost-cutting cross-link doesn't match.
  def assert_no_dead_cost_cta
    assert_no_match(%r{href="/cost(\?[^"]*)?"}, response.body)
  end
end
