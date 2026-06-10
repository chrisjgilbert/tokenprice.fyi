require "test_helper"

class TrendsControllerTest < ActionDispatch::IntegrationTest
  test "renders trends with rankings, movers and timeline" do
    get trends_url
    assert_response :success
    assert_select "h2", /Cheapest frontier models/
    assert_select "h2", /Recent price moves/
  end
end
