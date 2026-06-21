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

  test "how-pricing-works emits a self-canonical link that ignores query params" do
    get how_pricing_works_url(ref: "twitter")
    assert_response :success
    assert_select "link[rel=canonical][href=?]", how_pricing_works_url
  end

  test "how-pricing-works emits Article JSON-LD via the json_ld helper" do
    get how_pricing_works_url
    assert_response :success
    assert_select "script[type='application/ld+json']", minimum: 1
    # The json_ld helper emits compact (minified) JSON, unlike the old raw block.
    assert_includes @response.body, "\"@type\":\"Article\""
    assert_includes @response.body, "\"headline\":\"How LLM pricing works\""
  end
end
