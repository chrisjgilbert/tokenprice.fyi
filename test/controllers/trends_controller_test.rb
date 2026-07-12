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

  test "shows the recent price changes strip for a recent repricing" do
    provider = Provider.create!(name: "Strip Labs", slug: "strip-labs", accent: "#123456")
    model = provider.ai_models.create!(name: "Stripper One", slug: "stripper-one",
                                       tier: "mid", source: AiModel::MANUAL_SOURCE)
    model.price_points.create!(effective_on: Date.current - 5, input_per_mtok: 2, output_per_mtok: 8)
    model.price_points.create!(effective_on: Date.current - 1, input_per_mtok: 3, output_per_mtok: 8)

    get trends_url
    assert_response :success
    assert_select "section.changes .c-name", text: /Stripper One/
    assert_select "section.changes .c-leg", /\$2/  # old input rate on the strip
  end

  test "omits the price changes strip when nothing repriced recently" do
    get trends_url
    assert_response :success
    assert_select "section.changes", count: 0
  end

  test "sets a conditional-GET etag off the catalog freshness" do
    get trends_url

    assert_response :success
    assert response.etag.present?
  end

  test "editing a flagship's metadata busts the cache even with no price write" do
    get trends_url
    etag = response.etag

    # released_on sets a flagship's x-position but touches no price row. Advance
    # past the current second so the edit lands on a later Last-Modified — the
    # etag stamp is second-precision, as any HTTP cache validator is, and a real
    # admin edit is always seconds after the cached render.
    travel 2.seconds do
      ai_models(:opus).update!(released_on: ai_models(:opus).released_on - 1.day)
      get trends_url, headers: { "If-None-Match" => etag }
    end
    assert_response :success, "a frontier metadata edit must not 304 off the old etag"
  end
end
