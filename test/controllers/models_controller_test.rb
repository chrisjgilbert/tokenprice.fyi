require "test_helper"

class ModelsControllerTest < ActionDispatch::IntegrationTest
  test "index renders the Inertia grid with all listed models and the cheapest-frontier callout" do
    get root_url
    assert_response :success

    page = inertia_page
    assert_equal "Models/Index", page["component"]

    names = page["props"]["models"].map { |m| m["name"] }
    assert_includes names, "Claude Opus 4.8"
    assert_includes names, "DeepSeek V4 Pro"

    # DeepSeek blends cheaper than Opus, so it's the headline stat.
    assert_equal "DeepSeek V4 Pro", page["props"]["cheapestFrontier"]["name"]
  end

  test "index rows carry the grid fields, pre-sorted by blended price" do
    get root_url
    models = inertia_page["props"]["models"]

    blended = models.map { |m| m["blended"] }.compact
    assert_equal blended.sort, blended

    row = models.find { |m| m["name"] == "DeepSeek V4 Pro" }
    assert_equal "DeepSeek", row["provider"]
    assert_equal "/models/deepseek-v4-pro", row["url"]
    assert_equal "/providers/deepseek", row["providerUrl"]
    assert_equal "frontier", row["tier"]
    assert_in_delta 0.435, row["input"]
    assert_in_delta 0.87, row["output"]
    assert_equal 1_000_000, row["contextWindow"]
    assert_equal "2026-02-01", row["releasedOn"]
  end

  test "show renders a model and its price history chart" do
    get model_url(ai_models(:deepseek_v4))
    assert_response :success
    assert_select "h1", "DeepSeek V4 Pro"
    assert_select "svg" # history chart renders for a model with >1 snapshot
  end

  test "show returns 404 for an unknown slug" do
    get model_url(id: "does-not-exist")
    assert_response :not_found
  end

  test "index emits a canonical link and JSON-LD" do
    get root_url
    assert_response :success
    assert_select "link[rel=canonical]", count: 1
    assert_select "script[type='application/ld+json']", minimum: 1
    assert_includes @response.body, "\"@type\":\"ItemList\""
  end

  test "show emits Product JSON-LD" do
    get model_url(ai_models(:opus))
    assert_select "script[type='application/ld+json']", minimum: 1
    assert_includes @response.body, "\"@type\":\"Product\""
  end

  private

  # The props Inertia embeds in the page container div.
  def inertia_page
    JSON.parse(css_select("#app").first["data-page"])
  end
end
