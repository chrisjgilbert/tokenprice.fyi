require "test_helper"

class TrendsControllerTest < ActionDispatch::IntegrationTest
  test "renders trends page" do
    get trends_url
    assert_response :success
    assert_select "h1", /Pricing over time/
  end
end
