require "test_helper"

class ProvidersControllerTest < ActionDispatch::IntegrationTest
  test "shows a provider and its models" do
    get provider_url(providers(:anthropic))
    assert_response :success
    assert_select "h1", "Anthropic"
    assert_select "td", /Claude Opus 4.8/
  end

  test "emits a self-canonical and a dynamic meta description" do
    provider = providers(:anthropic)
    get provider_url(provider, ref: "twitter")
    assert_response :success
    assert_select "link[rel=canonical][href=?]", provider_url(provider)
    assert_select "meta[name=description][content*=?]", "Anthropic API pricing across"
    assert_select "meta[name=description][content*=?]", "input/output rates per 1M tokens"
  end

  test "renders a crawlable intro paragraph with the provider name and live model count" do
    provider = providers(:anthropic)
    get provider_url(provider)
    assert_response :success
    count = provider.ai_models.count
    assert_select "p", text: /#{Regexp.escape(provider.name)} API pricing for #{count} models/
    assert_select "p", text: /updated daily/
  end

  test "links to the guide and to the events timeline with descriptive anchors" do
    get provider_url(providers(:anthropic))
    assert_response :success
    assert_select "a[href=?]", guide_path
    assert_select "a[href=?]", events_path
  end

  test "emits a Home to Provider BreadcrumbList JSON-LD" do
    provider = providers(:anthropic)
    get provider_url(provider)
    assert_response :success
    assert_select "script[type='application/ld+json']", minimum: 1
    assert_includes @response.body, "\"@type\":\"BreadcrumbList\""
    assert_includes @response.body, provider_url(provider)
  end

  test "a price-less directory row renders not-yet-tracked, never $0" do
    get provider_url(providers(:anthropic))
    assert_response :success
    assert_select "td", text: /Pixel Forge 1/
    assert_match(/not yet tracked/i, @response.body)
    assert_no_match(/\$0\b/, css_select("tbody").to_s)
  end

  test "a price-less directory row sinks below priced rows on a price sort, both ways" do
    %w[asc desc].each do |dir|
      get provider_url(providers(:anthropic), sort: "output", dir: dir)
      assert_response :success
      # Index each row by whether it shows a real dollar figure; the price-less
      # Pixel Forge row must sit below every $-bearing (priced) row.
      rows = css_select("tbody tr").to_a
      forge_at = rows.index { |r| r.to_s.include?("Pixel Forge 1") }
      last_priced = rows.rindex { |r| r.to_s.match?(/\$\d/) }
      assert forge_at, "the price-less row should appear on the provider page"
      assert forge_at > last_priced,
        "a price-less row must sort below every priced row on output #{dir}"
    end
  end
end
