require "test_helper"

class TrendsControllerTest < ActionDispatch::IntegrationTest
  test "renders trends page" do
    get trends_url
    assert_response :success
    assert_select "h1", /Pricing over time/
  end

  test "emits a self-canonical link that ignores query params" do
    get trends_url(ref: "twitter")
    assert_response :success
    assert_select "link[rel=canonical][href=?]", trends_url
  end
end
