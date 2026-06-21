require "test_helper"

# The /why positioning essay was removed: it argued the case for the tool
# rather than teaching anything, so it's cut. Its one durable point — that this
# is an independent, dated price record — folds into the site footer.
# Guard against the route, helpers, nav entry, or sitemap URL creeping back.
class WhyRemovedTest < ActionDispatch::IntegrationTest
  test "/why is not routable" do
    # With the route gone the app has nothing to dispatch to; in the test
    # environment that surfaces as a 404 rather than a raised RoutingError.
    get "/why"
    assert_response :not_found
  end

  test "why_path / why_url helpers no longer exist" do
    assert_not Rails.application.routes.url_helpers.respond_to?(:why_path)
    assert_not Rails.application.routes.url_helpers.respond_to?(:why_url)
  end

  test "the Learn nav no longer lists 'Why this exists'" do
    get learn_path
    assert_response :success
    assert_no_match(/Why this exists/, response.body)
  end

  test "the footer carries the folded independence line" do
    get root_path
    assert_response :success
    assert_match(/Independent price record, not affiliated with any provider/, response.body)
  end
end
