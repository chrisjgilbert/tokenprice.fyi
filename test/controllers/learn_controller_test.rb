require "test_helper"

class LearnControllerTest < ActionDispatch::IntegrationTest
  test "the learn index is a lean directory of the three real explainers" do
    get learn_url
    assert_response :success
    # Links to each of the three built explainers.
    assert_select "a[href=?]", how_pricing_works_path
    assert_select "a[href=?]", learn_feature_costs_path
    assert_select "a[href=?]", learn_cost_cutting_path
    # The standalone /cost estimator was removed; no dead reference remains.
    assert_select ".led-cta", false
    assert_no_match(%r{href="/cost(\?[^"]*)?"}, response.body)
  end

  test "the learn index drops the vaporware stub concepts and series chrome" do
    get learn_url
    assert_no_match(/Prompt caching/, response.body)
    assert_no_match(/Batch processing/, response.body)
    assert_no_match(/Reasoning/, response.body)
    assert_no_match(/What an AI agent actually costs/, response.body)
    assert_no_match(/Next up/, response.body)
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
