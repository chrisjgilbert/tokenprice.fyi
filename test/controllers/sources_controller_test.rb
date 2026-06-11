require "test_helper"

class SourcesControllerTest < ActionDispatch::IntegrationTest
  test "renders the sources page" do
    get sources_url
    assert_response :success
    assert_select "h1", /Where the numbers come from/
  end

  test "lists each distinct price point source as an https link with its counts" do
    get sources_url

    # Fixture sources are bare domain strings; the page renders them as links.
    assert_select "a[href=?]", "https://anthropic.com/pricing", text: "anthropic.com/pricing"
    assert_select "a[href=?]", "https://api-docs.deepseek.com"
    assert_select "a[href=?]", "https://deepseek.ai/blog"

    assert_select "td", text: "Anthropic"
  end

  test "buckets recognised first-party and unknown domains into the right groups" do
    # An unknown domain must land under "Aggregators & press", never first-party.
    ai_models(:opus).price_points.create!(
      effective_on: "2026-01-01", input_per_mtok: 1, output_per_mtok: 2,
      source: "openrouter.ai/x-ai/grok-4.20"
    )
    get sources_url

    assert_select "section[aria-label='Aggregators & press']" do
      assert_select "a[href=?]", "https://openrouter.ai/x-ai/grok-4.20"
    end
    # Provider-website subdomains stay first-party (api-docs.deepseek.com → deepseek.com).
    assert_select "section[aria-label='Provider pricing pages']" do
      assert_select "a[href=?]", "https://api-docs.deepseek.com"
    end
    # No community-dataset sources are seeded, so the group is omitted entirely.
    assert_select "section[aria-label='Community datasets']", count: 0
  end

  test "renders a source that is not a domain as plain text, not a link" do
    ai_models(:opus).price_points.create!(
      effective_on: "2026-01-02", input_per_mtok: 1, output_per_mtok: 2,
      source: "manual estimate"
    )
    get sources_url

    assert_select "td", text: "manual estimate"
    assert_select "a", text: "manual estimate", count: 0
  end

  test "credits the acknowledged upstream sources" do
    get sources_url

    assert_select "a[href=?]", "https://web.archive.org"
    assert_select "a[href=?]", "https://openrouter.ai"
    assert_select "a[href=?]", "https://github.com/BerriAI/litellm"
  end

  test "is listed in the sitemap" do
    get sitemap_url
    assert_includes @response.body, sources_url
  end

  test "is linked from the footer" do
    get root_url
    assert_select "footer a[href=?]", sources_path, text: "Data sources"
  end
end
