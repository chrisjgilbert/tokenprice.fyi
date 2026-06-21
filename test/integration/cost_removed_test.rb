require "test_helper"

# The standalone /cost estimator page was removed: its monthly-bill framing and
# ranking table are retired. The per-call pricing math (CostEstimate) survives
# and is consumed by GuideCost (the model-detail embed was later removed too).
# Guard against the route, helpers, nav entry, or sitemap URL creeping back.
class CostRemovedTest < ActionDispatch::IntegrationTest
  test "/cost is not routable" do
    # With the route gone the app has nothing to dispatch to; in the test
    # environment that surfaces as a 404 rather than a raised RoutingError.
    get "/cost"
    assert_response :not_found
  end

  test "cost_path / cost_url helpers no longer exist" do
    assert_not Rails.application.routes.url_helpers.respond_to?(:cost_path)
    assert_not Rails.application.routes.url_helpers.respond_to?(:cost_url)
  end

  test "the primary nav no longer carries an Estimate item" do
    get root_path
    assert_response :success
    # Scope to the desktop primary nav links region so we don't match unrelated
    # copy elsewhere on the page.
    assert_select ".tp-nav-links" do
      assert_select "a", text: "Estimate", count: 0
    end
  end

  test "the sitemap no longer lists the cost URL" do
    get sitemap_path(format: :xml)
    assert_response :success
    assert_no_match(%r{<loc>[^<]*/cost</loc>}, response.body)
  end

  # The model-detail estimate embed (the req/month slider and its Turbo Frame)
  # was removed — the last fabricated-volume surface. Its route is gone, so the
  # frame endpoint must 404 and the model_estimate_path helper must not exist.
  test "/models/:id/estimate is not routable" do
    get "/models/claude-opus-4-8/estimate"
    assert_response :not_found
  end

  test "model_estimate_path / model_estimate_url helpers no longer exist" do
    assert_not Rails.application.routes.url_helpers.respond_to?(:model_estimate_path)
    assert_not Rails.application.routes.url_helpers.respond_to?(:model_estimate_url)
  end

  test "the model detail page no longer mounts the estimate embed" do
    get model_url("claude-opus-4-8")
    assert_response :success
    assert_select "section.embed-wrap", false
    assert_select "[data-controller~='cost-form']", false
    # Price history survives.
    assert_select "h2", text: "Price history"
  end
end
