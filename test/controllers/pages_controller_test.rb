require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "thought pieces are hidden from the public" do
    get why_url
    assert_response :not_found

    get which_model_url
    assert_response :not_found
  end

  test "renders the why page for admin preview" do
    sign_in_admin
    get why_url
    assert_response :success
    assert_select "h1", /LLM costs are decided in the dark/
  end

  test "renders the which-model page for admin preview" do
    sign_in_admin
    get which_model_url
    assert_response :success
    assert_select "h1"
  end
end
