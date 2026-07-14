require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "the legacy which-model URL 301s to the homepage" do
    get "/which-model"
    assert_response :moved_permanently
    assert_redirected_to "/"
  end

  test "the removed guide URLs 301 to the homepage" do
    [ "/guide", "/guide/rag", "/guide/coding-agent", "/guide/coding_agent" ].each do |path|
      get path
      assert_response :moved_permanently, "expected #{path} to redirect"
      assert_redirected_to "/"
    end
  end

  test "how-pricing-works is public" do
    get how_pricing_works_url
    assert_response :success
    assert_select "h1", /How LLM pricing works/
  end

  test "llms.txt renders as plain text" do
    get llms_txt_url
    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_match "llms.txt — tokenprice.fyi", response.body
    assert_match root_url, response.body
  end

  test "llms.txt lists every category tab URL and describes the two tiers" do
    get llms_txt_url
    assert_response :success
    body = response.body
    assert_match image_generation_url, body
    assert_match speech_to_text_url, body
    assert_match embeddings_url, body
    assert_match video_generation_url, body
    # Frames the product as a cross-category record, not an LLM-only tracker.
    assert_match(/price record of AI model APIs/i, body)
    assert_no_match(/independent LLM API pricing tracker/i, body)
  end

  test "llms.txt no longer advertises a public JSON API" do
    get llms_txt_url
    assert_no_match(%r{/api/v1}, response.body)
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
