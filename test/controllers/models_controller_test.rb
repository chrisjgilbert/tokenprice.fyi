require "test_helper"

class ModelsControllerTest < ActionDispatch::IntegrationTest
  test "index lists models with the cheapest-frontier callout" do
    get root_url
    assert_response :success
    assert_select "h1", /Compare pricing across/
    assert_select "tbody td", /Claude Opus 4.8/
  end

  test "hero is the price-index hero with a guide-primary CTA and a pricing-explainer CTA" do
    get root_url
    assert_response :success
    # Primary CTA into the guide — the pivot survives on a price-index hero.
    assert_select ".hero-cta a[href=?]", guide_path, text: /Find a model for your task/
    # Secondary CTA into the pricing explainer.
    assert_select ".hero-cta a[href=?]", how_pricing_works_path, text: /How pricing works/
  end

  test "hero subtitle renders the dynamic model and provider counts, never a static 40+" do
    get root_url
    assert_response :success
    count = AiModel.listed.count
    assert_select ".hero-sub", /models across/
    assert_select ".hero-sub .num", text: count.to_s
    assert_select ".hero-sub", text: /40\+/, count: 0
  end

  test "index emits an owned meta description targeting the head term and providers" do
    get root_url
    assert_response :success
    # An owned description, not the layout default fallback.
    assert_select "meta[name=description][content*=?]", "LLM API token prices"
    assert_select "meta[name=description][content*=?]", "Claude"
    assert_select "meta[name=description][content*=?]", "updated daily"
  end

  test "latest-changes widget is present and the market-event timeline strip is gone" do
    get root_url
    assert_response :success
    assert_select ".hero-card-tag", /Latest changes/
    # Dropped per audit #6: the thin, redundant market-event strip.
    assert_select ".hero-timeline", count: 0
    assert_select ".hero-card", text: /Recent activity/, count: 0
  end

  test "hero has exactly one Trends entry point" do
    get root_url
    assert_response :success
    assert_select ".hero-card a[href=?]", trends_path, count: 1
  end

  test "footer carries the deck sourcing disclaimer" do
    get root_url
    assert_response :success
    assert_select ".tp-foot",
      text: /sourced from provider price pages · costs are per-call estimates, never a monthly bill/
  end

  test "the beta flag is gone from the chrome" do
    get root_url
    assert_response :success
    assert_select ".tp-beta", count: 0
    assert_select ".tp-foot-beta", count: 0
    assert_no_match(/data is still being sense-checked/, response.body)
  end

  test "index can be filtered by tier" do
    get root_url(tier: "frontier")
    assert_response :success
  end

  test "index can be sorted" do
    get root_url(sort: "output", dir: "desc")
    assert_response :success
  end

  test "index can be sorted by change since launch and renders delta badges" do
    get root_url(sort: "change", dir: "asc")
    assert_response :success
    assert_select "th.sort-active", text: /since launch/i
    # DeepSeek V4 Pro's 75% cut renders as a delta pill in the new column.
    assert_select ".tp-delta", minimum: 1
  end

  test "index can be filtered to a single provider" do
    get root_url(providers: ["anthropic"])
    assert_response :success
    assert_select "tbody td", text: /Claude Opus 4.8/
    assert_select "tbody td", text: /DeepSeek/, count: 0
  end

  test "index can be filtered to multiple providers" do
    get root_url(providers: ["anthropic", "deepseek"])
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
    get root_url(providers: {evil: "payload"})
    assert_response :success
    assert_select "tbody td", text: /Claude Opus 4.8/
    assert_select "tbody td", text: /DeepSeek V4 Pro/
  end

  test "index ignores unknown provider slugs" do
    get root_url(providers: ["not-a-provider"])
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
    get root_url(q: "claude", providers: ["anthropic"], sort: "input", dir: "desc")
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
    assert_select "thead a[data-turbo-frame=models]", count: 9
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
    get root_url(q: "opus", providers: ["deepseek"])
    assert_select "td", /No models match your filters/
  end

  test "show renders a model and its price history chart" do
    get model_url(ai_models(:deepseek_v4))
    assert_response :success
    assert_select "h1", "DeepSeek V4 Pro"
    assert_select "svg"
  end

  test "show emits a self-canonical link that ignores query params" do
    get model_url(ai_models(:opus), ref: "twitter")
    assert_response :success
    assert_select "link[rel=canonical][href=?]", model_url(ai_models(:opus))
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

  test "index canonicalizes every filtered/sorted state to the bare root URL" do
    get root_url(tier: "frontier", sort: "input", dir: "desc")
    assert_response :success
    assert_select "link[rel=canonical][href=?]", root_url
  end

  test "show emits Product JSON-LD" do
    get model_url(ai_models(:opus))
    assert_select "script[type='application/ld+json']", minimum: 1
    assert_includes @response.body, "\"@type\":\"Product\""
  end

  test "show emits an AggregateOffer spanning input and output prices" do
    model = ai_models(:opus) # input 5, output 25, cached 0.5 per 1M tokens
    get model_url(model)
    assert_response :success

    body = @response.body
    assert_includes body, "\"@type\":\"AggregateOffer\""
    assert_includes body, "\"priceCurrency\":\"USD\""
    # offerCount is derived from the non-nil price set: input + output + cached = 3.
    assert_includes body, "\"offerCount\":3"
    # lowPrice = min over the priced set, highPrice = max over the same set.
    assert_includes body, "\"lowPrice\":\"#{model.current_cached_input}\""
    assert_includes body, "\"highPrice\":\"#{model.current_output}\""
    # Availability carried over from the old single Offer.
    assert_includes body, "\"availability\":\"https://schema.org/InStock\""
    # The unit (per 1M tokens) must be expressed so the price isn't ambiguous.
    assert_match(/per 1M tokens/i, body)
    # No stale single-Offer price field that hid the output cost.
    assert_not_includes body, "\"@type\":\"Offer\""
  end

  test "show AggregateOffer drops the nil cached component from count and breakdown" do
    # A model with input + output but NO cached input (the only nilable price
    # column): the cached component must be absent from offerCount and from the
    # price breakdown, and no non-numeric em-dash placeholder (from usd_plain(nil))
    # may land in the structured-data price text.
    model = ai_models(:opus)
    model.current_price.update!(cached_input_per_mtok: nil)
    get model_url(model)
    assert_response :success

    json_ld = @response.body[/<script type="application\/ld\+json">(.+?)<\/script>/m, 1]
    assert json_ld, "expected Product JSON-LD on the show page"
    # input + output only (cached dropped) → offerCount 2.
    assert_includes json_ld, "\"offerCount\":2"
    # The dropped cached component must not appear at all in the breakdown.
    assert_not_includes json_ld, "cached input"
    # No em-dash placeholder for a nil price value in the breakdown text.
    assert_not_includes json_ld, "input —"
    assert_not_includes json_ld, "—\""
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
