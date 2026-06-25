require "test_helper"

# The world-map page was removed: country is a column, not a destination.
# Guard against the route, helpers, or nav entry creeping back.
class MapRemovedTest < ActionDispatch::IntegrationTest
  test "/map is not routable" do
    # With the route gone the app has nothing to dispatch to; in the test
    # environment that surfaces as a 404 rather than a 200 render.
    get "/map"
    assert_response :not_found
  end

  test "map_path / map_url helpers no longer exist" do
    assert_not Rails.application.routes.url_helpers.respond_to?(:map_path)
    assert_not Rails.application.routes.url_helpers.respond_to?(:map_url)
  end

  test "the Learn nav no longer lists the map" do
    get learn_path
    assert_response :success
    assert_no_match(/Where do models come from\?/, response.body)
  end
end
