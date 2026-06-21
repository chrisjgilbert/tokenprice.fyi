require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "which-model 301s to the guide" do
    get "/which-model"
    assert_response :moved_permanently
    assert_redirected_to "/guide"
  end

  test "how-pricing-works is public" do
    get how_pricing_works_url
    assert_response :success
    assert_select "h1", /How LLM pricing works/
  end
end
