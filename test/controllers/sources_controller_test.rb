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

    # The anthropic.com/pricing row covers one model / one price point from Anthropic.
    assert_select "tr" do
      assert_select "td", text: "Anthropic"
    end
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
