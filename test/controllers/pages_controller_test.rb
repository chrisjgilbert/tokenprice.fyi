require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "the why page is public" do
    get why_url
    assert_response :success
    assert_select "h1", /LLM costs are decided in the dark/
  end

  test "the which-model guide is public" do
    get which_model_url
    assert_response :success
    assert_select "h1", /Which model should you actually use/
    assert_select ".wm-tldr"
  end

  test "how-pricing-works is public" do
    get how_pricing_works_url
    assert_response :success
    assert_select "h1", /How LLM pricing works/
  end
end
