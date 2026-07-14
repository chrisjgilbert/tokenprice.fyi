require "test_helper"

# The global chrome (footer, Organization JSON-LD, default meta) must describe
# the whole product — a price record across seven categories — not just the
# per-token language tier. These render on every page via the layout.
class ChromeFramingTest < ActionDispatch::IntegrationTest
  test "footer tagline no longer claims per-1M-token units site-wide" do
    get root_url
    assert_response :success
    assert_select "footer.tp-foot" do
      assert_select "span", text: /USD per 1M tokens/, count: 0
    end
  end

  test "Organization JSON-LD describes the cross-category record, not an LLM-only tracker" do
    get root_url
    assert_response :success
    body = @response.body
    assert_no_match(/Independent LLM API pricing tracker/, body)
    assert_match(/price record of AI model APIs/i, body)
  end

end
