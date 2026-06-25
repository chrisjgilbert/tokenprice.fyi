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

  test "how-pricing-works resolves the catalog last_modified once per request" do
    # The conditional-GET key needs the catalog freshness timestamp; it must be
    # resolved a single time per request, so the page issues one
    # PricePoint.maximum query rather than several.
    calls = 0
    counting = Module.new do
      define_method(:last_modified) { calls += 1; super() }
    end
    PriceCatalog.singleton_class.prepend(counting)
    begin
      get how_pricing_works_url
      assert_response :success
    ensure
      counting.send(:define_method, :last_modified) { super() }
    end
    assert_equal 1, calls,
      "PriceCatalog.last_modified must be resolved once per request, not twice"
  end

  test "how-pricing-works supports conditional GET after the memoization" do
    get how_pricing_works_url
    assert_response :success
    etag = response.headers["ETag"]
    last_mod = response.headers["Last-Modified"]
    get how_pricing_works_url,
        headers: { "If-None-Match" => etag, "If-Modified-Since" => last_mod }
    assert_response :not_modified
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
