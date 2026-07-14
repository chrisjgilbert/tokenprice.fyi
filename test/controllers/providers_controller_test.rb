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
    # Category-neutral: no longer claims per-1M-token rates for every model.
    assert_select "meta[name=description][content*=?]", "native rates"
    assert_select "meta[name=description]" do |tags|
      assert_no_match(/input\/output rates per 1M tokens/, tags.first["content"])
    end
  end

  test "a provider's models are grouped by category, each with its own columns" do
    get provider_url(providers(:anthropic))
    assert_response :success
    # anthropic fixtures span language, image, speech, embeddings, etc.
    assert_select "h2", text: /Language models/
    assert_select "h2", text: /Image generation/
    assert_select "h2", text: /Speech to text/
  end

  test "a single-category provider drops the redundant category heading" do
    # deepseek fixtures are all language models — one group, so the lone
    # "Language models" heading would just label the only table on the page.
    get provider_url(providers(:deepseek))
    assert_response :success
    assert_select "td a", /Uncached Mid/
    assert_select "h2", false
  end

  test "a provider's image models show their native price, not blank token cells" do
    get provider_url(providers(:anthropic))
    assert_response :success
    # image_priced renders its native headline under the image group's pricing
    # column — never a blank Input/Output cell.
    assert_select "td", text: %r{\$0\.04 / image}
  end

  test "renders the description blurb and uses it for the meta description when present" do
    providers(:anthropic).update!(description: "Builds the Claude family across the Opus, Sonnet, and Haiku tiers.")
    get provider_url(providers(:anthropic))
    assert_response :success
    assert_select "p", text: /Builds the Claude family across the Opus, Sonnet, and Haiku tiers\./
    assert_select "meta[name=description][content*=?]", "Builds the Claude family across the Opus"
  end

  test "renders a crawlable intro paragraph with the provider name and live model count" do
    provider = providers(:anthropic)
    get provider_url(provider)
    assert_response :success
    count = provider.ai_models.count
    assert_select "p", text: /#{Regexp.escape(provider.name)} API pricing for #{count} models/
    assert_select "p", text: /updated daily/
  end

  test "links to the events timeline with a descriptive anchor" do
    get provider_url(providers(:anthropic))
    assert_response :success
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

  test "stamps when the data was last updated and offers a prefilled report link" do
    provider = providers(:anthropic)
    get provider_url(provider)
    assert_response :success
    assert_select "time", text: /Data updated/
    assert_select "a[href^=?]", "mailto:#{ApplicationHelper::REPORT_EMAIL}", text: "Report a problem" do
      assert_select ":match('href', ?)", "data%20issue%3A%20#{ERB::Util.url_encode(provider.name)}"
    end
  end
end
