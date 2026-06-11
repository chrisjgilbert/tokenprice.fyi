require "test_helper"

class ModelsControllerTest < ActionDispatch::IntegrationTest
  test "index lists models with the cheapest-frontier callout" do
    get root_url
    assert_response :success
    assert_select "h1", /million tokens cost/
    assert_select "tbody td", /Claude Opus 4.8/
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
    assert_select "tbody td", text: /Claude Opus 4.8/
    assert_select "tbody td", text: /DeepSeek/, count: 0
  end

  test "index can be filtered to multiple providers" do
    get root_url(providers: [ "anthropic", "deepseek" ])
    assert_response :success
    assert_select "tbody td", text: /Claude Opus 4.8/
    assert_select "tbody td", text: /DeepSeek V4 Pro/
  end

  test "index accepts a scalar providers param" do
    get root_url(providers: "anthropic")
    assert_response :success
    assert_select "tbody td", text: /Claude Opus 4.8/
    assert_select "tbody td", text: /DeepSeek/, count: 0
  end

  test "index ignores a hash-shaped providers param" do
    get root_url(providers: { evil: "payload" })
    assert_response :success
    assert_select "tbody td", text: /Claude Opus 4.8/
    assert_select "tbody td", text: /DeepSeek V4 Pro/
  end

  test "index ignores unknown provider slugs" do
    get root_url(providers: [ "not-a-provider" ])
    assert_response :success
    assert_select "tbody td", text: /Claude Opus 4.8/
  end

  test "index treats punctuation-only queries as no filter" do
    get root_url(q: "!!!")
    assert_response :success
    assert_select "tbody td", text: /Claude Opus 4.8/
    assert_select "tbody td", text: /DeepSeek V4 Pro/
  end

  test "index never lists retired models, even when searched for" do
    get root_url
    assert_select "tbody td", text: /Claude Instant/, count: 0

    get root_url(q: "instant")
    assert_select "td", /No models match your filters/
  end

  test "sort links carry the active filters and sort state rides in the form" do
    get root_url(q: "claude", providers: [ "anthropic" ], sort: "input", dir: "desc")
    assert_response :success
    assert_select "thead a[href*='q=claude']"
    assert_select "thead a[href*='providers%5B%5D=anthropic']"
    assert_select "input[type=hidden][name=sort][value=input][form=filters]", count: 1
    assert_select "input[type=hidden][name=dir][value=desc][form=filters]", count: 1
  end

  test "default sort state is omitted from the filter form" do
    get root_url
    assert_select "input[type=hidden][name=sort]", count: 0
    assert_select "input[type=hidden][name=dir]", count: 0
  end

  test "frame navigation is scoped so row links break out of the frame" do
    get root_url
    assert_select "turbo-frame#models[target=_top]", count: 1
    assert_select "thead a[data-turbo-frame=models]", count: 8
    assert_select "form#filters[data-turbo-frame=models]", count: 1
  end

  test "index can be searched" do
    get root_url(q: "deepseek")
    assert_select "tbody td", text: /DeepSeek V4 Pro/
    assert_select "tbody td", text: /Claude/, count: 0
  end

  test "index search tolerates typos" do
    get root_url(q: "antropic")
    assert_select "tbody td", text: /Claude Opus 4.8/
    assert_select "tbody td", text: /DeepSeek/, count: 0
  end

  test "index shows an empty state when nothing matches" do
    get root_url(q: "zzzzzz")
    assert_response :success
    assert_select "td", /No models match your filters/
  end

  test "index caps pathological search queries" do
    get root_url(q: "abc " * 2_000)
    assert_response :success
  end

  test "search and provider filters combine" do
    get root_url(q: "opus", providers: [ "deepseek" ])
    assert_select "td", /No models match your filters/
  end

  test "show renders a model and its price history chart" do
    get model_url(ai_models(:deepseek_v4))
    assert_response :success
    assert_select "h1", "DeepSeek V4 Pro"
    assert_select "svg"
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

  test "show renders the computed insights section" do
    get model_url(ai_models(:deepseek_v4))
    assert_response :success
    assert_select "h2", text: "Where it sits"
    assert_select "p", text: /Cheapest frontier model/
  end

  test "show renders editorial facets when present" do
    ai_models(:opus).update!(
      strengths: "Highly autonomous agentic work",
      best_for: "Long-horizon coding",
      limitations: "Premium pricing"
    )
    get model_url(ai_models(:opus))
    assert_response :success
    assert_select "dt", text: "Strengths"
    assert_select "dd", text: "Highly autonomous agentic work"
    assert_select "dt", text: "Best for"
    assert_select "dt", text: "Limitations"
  end
end
