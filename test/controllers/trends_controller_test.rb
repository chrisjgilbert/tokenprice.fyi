require "test_helper"

class TrendsControllerTest < ActionDispatch::IntegrationTest
  test "renders the flagship price-over-time chart" do
    get trends_url

    assert_response :success
    assert_select "h1", /Flagship prices over time/
    # One stepped line per provider with a frontier history (Anthropic, DeepSeek).
    assert_select "g.flagship-line", count: 2
    assert_select ".trends-legend-item", count: 2
  end

  test "the backing table lists flagships newest reign first, linking each model" do
    get trends_url

    assert_response :success
    assert_select ".trends-summary-name", text: "Anthropic"
    # Fable 5 (Jun 2026) is the current Anthropic flagship, so it heads the table.
    assert_select ".trends-detail", text: /Claude Fable 5/
    assert_select "a.trends-model-link[href=?]", model_path("claude-opus-4-8")
  end

  test "sets a conditional-GET etag off the catalog freshness" do
    get trends_url

    assert_response :success
    assert response.etag.present?
  end
end
