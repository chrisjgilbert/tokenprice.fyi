require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "renders the why page" do
    get why_url
    assert_response :success
    assert_select "h1", /LLM costs are decided in the dark/
  end

  test "renders the which-model page" do
    get which_model_url
    assert_response :success
    assert_select "h1"
  end
end
