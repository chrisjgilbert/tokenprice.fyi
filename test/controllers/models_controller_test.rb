require "test_helper"

class ModelsControllerTest < ActionDispatch::IntegrationTest
  test "index lists models with the cheapest-frontier callout" do
    get root_url
    assert_response :success
    assert_select "h1", /million tokens cost/
    assert_select "tbody th[scope=row]", /Claude Opus 4.8/
  end

  test "index can be filtered by tier" do
    get root_url(tier: "frontier")
    assert_response :success
  end

  test "index can be sorted" do
    get root_url(sort: "output", dir: "desc")
    assert_response :success
  end

  test "index can be filtered to a single provider" do
    get root_url(providers: [ "anthropic" ])
    assert_response :success
    assert_select "tbody th[scope=row]", text: /Claude Opus 4.8/
    assert_select "tbody th[scope=row]", text: /DeepSeek/, count: 0
  end

  test "index can be filtered to multiple providers" do
    get root_url(providers: [ "anthropic", "deepseek" ])
    assert_select "tbody th[scope=row]", text: /Claude Opus 4.8/
    assert_select "tbody th[scope=row]", text: /DeepSeek V4 Pro/
  end

  test "index ignores unknown provider slugs" do
    get root_url(providers: [ "not-a-provider" ])
    assert_response :success
    assert_select "tbody th[scope=row]", text: /Claude Opus 4.8/
  end

  test "index can be searched" do
    get root_url(q: "deepseek")
    assert_select "tbody th[scope=row]", text: /DeepSeek V4 Pro/
    assert_select "tbody th[scope=row]", text: /Claude/, count: 0
  end

  test "index search tolerates typos" do
    get root_url(q: "antropic")
    assert_select "tbody th[scope=row]", text: /Claude Opus 4.8/
    assert_select "tbody th[scope=row]", text: /DeepSeek/, count: 0
  end

  test "index shows an empty state when nothing matches" do
    get root_url(q: "zzzzzz")
    assert_response :success
    assert_select "td", /No models match your filters/
  end

  test "search and provider filters combine" do
    get root_url(q: "opus", providers: [ "deepseek" ])
    assert_select "td", /No models match your filters/
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
    get root_url(sort: "input", dir: "desc")
    assert_response :success
    assert_select "link[rel=canonical]", count: 1
    assert_select "script[type='application/ld+json']", minimum: 1
  end

  test "show emits Product JSON-LD" do
    get model_url(ai_models(:opus))
    assert_select "script[type='application/ld+json']", minimum: 1
    assert_includes @response.body, "\"@type\":\"Product\""
  end
end
