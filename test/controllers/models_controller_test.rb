require "test_helper"

class ModelsControllerTest < ActionDispatch::IntegrationTest
  test "index lists models with the cheapest-frontier callout" do
    get root_url
    assert_response :success
    assert_select "h1", /LLM API pricing, tracked from launch/
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

  test "hero card has exactly one primary call to action" do
    get root_url
    assert_response :success
    # The CTA links to the primary event's destination (its model page or source
    # URL), falling back to the events timeline; there is always exactly one.
    assert_select ".hero-card a.tp-btn", count: 1
  end

  test "hero surfaces a price change among the latest events" do
    get root_url
    assert_response :success
    # The DeepSeek 75% cut (2026-05-31) is one of the two most recent events.
    assert_select ".hero-card .hero-card-kind-chip.reprice", /Price change/
    assert_select ".hero-card", /DeepSeek V4 Pro repriced/
  end

  test "the hero (and its price-change feed) is skipped on Turbo Frame refreshes" do
    get root_url, headers: { "Turbo-Frame" => "models" }
    assert_response :success
    assert_select ".hero-card", count: 0
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
    assert_select "th.sort-active", text: /Δ input/i
    # DeepSeek V4 Pro's 75% cut renders as a delta pill in the new column.
    assert_select ".tp-delta", minimum: 1
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
    get root_url(q: "claude", providers: [ "anthropic" ], sort: "input", dir: "asc")
    assert_response :success
    assert_select "thead a[href*='q=claude']"
    assert_select "thead a[href*='providers%5B%5D=anthropic']"
    assert_select "input[type=hidden][name=sort][value=input][form=filters]", count: 1
    assert_select "input[type=hidden][name=dir][value=asc][form=filters]", count: 1
  end

  test "default sort state is omitted from the filter form" do
    get root_url
    assert_select "input[type=hidden][name=sort]", count: 0
    assert_select "input[type=hidden][name=dir]", count: 0
  end

  test "frame navigation is scoped so row links break out of the frame" do
    get root_url
    assert_select "turbo-frame#models[target=_top]", count: 1
    assert_select "thead a[data-turbo-frame=models]", count: 7
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

  test "index can be filtered to multimodal models" do
    get root_url(modality: "multimodal")
    assert_response :success
    # The Sonnet fixture is multimodal (text, image in → text out).
    assert_select "tbody td", text: /Guide Sonnet Fixture/
    # Text-only models drop out of a multimodal-only view.
    assert_select "tbody td", text: /DeepSeek V4 Pro/, count: 0
    assert_select "tbody td", text: /Claude Opus 4.8/, count: 0
  end

  test "index ignores an unknown modality filter" do
    get root_url(modality: "not-a-class")
    assert_response :success
    assert_select "tbody td", text: /Guide Sonnet Fixture/
    assert_select "tbody td", text: /DeepSeek V4 Pro/
  end

  test "index only offers modality facets present among listed models" do
    get root_url
    assert_response :success
    # text, multimodal, and the price-less image-generation directory row are
    # present in fixtures; a class absent from listed models is not offered.
    assert_select "input[name=modality][value=multimodal]"
    assert_select "input[name=modality][value=image_generation]"
    assert_select "input[name=modality][value=video_generation]", count: 0
  end

  test "index renders a modality badge on multimodal rows only" do
    get root_url
    assert_response :success
    assert_select ".tp-modality-badge", minimum: 1
  end

  test "the modality filter rides in the etag so filtered views do not share a 304" do
    get root_url(modality: "multimodal")
    assert_response :success
    multimodal_etag = @response.headers["ETag"]

    get root_url(modality: "text")
    assert_response :success
    text_etag = @response.headers["ETag"]

    assert_not_equal multimodal_etag, text_etag,
      "different modality filters must not collide on one conditional-GET cache key"
  end

  test "show renders the modality badge for a multimodal model" do
    get model_url(ai_models(:sonnet))
    assert_response :success
    assert_select ".tp-modality-badge", text: "Multimodal"
  end

  test "show omits the modality badge for a plain text model" do
    get model_url(ai_models(:opus))
    assert_response :success
    assert_select ".tp-modality-badge", count: 0
  end

  test "show renders a model and its price history chart" do
    get model_url(ai_models(:deepseek_v4))
    assert_response :success
    assert_select "h1", "DeepSeek V4 Pro"
    assert_select "svg"
  end

  test "show renders a native-priced directory model's price, skipping the per-token history" do
    get model_url(ai_models(:priced_image_gen))
    assert_response :success
    assert_match %r{\$0\.04 / image}, @response.body
    # The per-token sections would chart $0.00 on NULL text rates, so they're omitted.
    assert_select "h2", text: "Price history", count: 0
    assert_select "h2", text: "Snapshots", count: 0
    assert_no_match(/\$0\.00/, @response.body)
  end

  test "show mounts the interactive price-chart controller with its data" do
    # The chart is progressively enhanced: the controller plus the serialized
    # price points (for the hover crosshair/tooltip) ride on the container.
    get model_url(ai_models(:deepseek_v4))
    assert_response :success
    assert_select "[data-controller~='price-chart']" do
      assert_select "[data-price-chart-target='overlay']"
      assert_select "[data-price-chart-target='tooltip']"
    end
    # The points value carries the dated price labels the tooltip renders.
    assert_select "[data-price-chart-points-value*='date']"
  end

  test "show always renders the chart, even with a single price on record" do
    # Opus has one price point. The chart must still render as an SVG rather
    # than falling back to a 'appears once a price changes' message.
    model = ai_models(:opus)
    assert_equal 1, model.price_points.size, "fixture should have a lone price point"
    get model_url(model)
    assert_response :success
    assert_select "svg"
    assert_no_match(/appears once a price changes/, @response.body)
    # With a single point no lines are drawn, so the solid/dashed legend is
    # withheld — it would describe line styles that aren't on the chart.
    assert_select "span", text: /Input \(solid\)/, count: 0
  end

  test "show lists the extra billed dimensions with their units when present" do
    get model_url(ai_models(:sonnet))
    assert_response :success
    assert_select ".tp-also-billed" do
      assert_select "*", text: /Cache write/
      assert_select "*", text: /Image input/
      assert_select "*", text: %r{/ image}
      assert_select "*", text: %r{/ 1M}
    end
  end

  test "show omits the also-billed block for a model with no extra dimensions" do
    get model_url(ai_models(:opus))
    assert_response :success
    assert_select ".tp-also-billed", count: 0
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

  test "a price-less directory row sinks below priced rows on output desc (the default)" do
    get root_url(sort: "output", dir: "desc")
    assert_response :success
    names = css_select("tbody tr td .tp-model-name").map { |n| n.text.strip }
    forge_at = names.index { |n| n.include?("Pixel Forge 1") }
    # Both Forge rows lack a per-token rate and sink; compare against the last
    # token-priced (non-Forge) row.
    last_priced = names.rindex { |n| !n.include?("Pixel Forge") }
    assert forge_at, "the price-less image-gen row should be listed"
    assert forge_at > last_priced,
      "a price-less row must sort below every priced row on output desc"
  end

  test "a price-less directory row sinks below priced rows on output asc" do
    get root_url(sort: "output", dir: "asc")
    assert_response :success
    names = css_select("tbody tr td .tp-model-name").map { |n| n.text.strip }
    forge_at = names.index { |n| n.include?("Pixel Forge 1") }
    last_priced = names.rindex { |n| !n.include?("Pixel Forge") }
    assert forge_at > last_priced,
      "a price-less row must sort below every priced row on output asc"
  end

  test "a price-less directory row sinks below priced rows on input in both directions" do
    %w[asc desc].each do |dir|
      get root_url(sort: "input", dir: dir)
      assert_response :success
      names = css_select("tbody tr td .tp-model-name").map { |n| n.text.strip }
      forge_at = names.index { |n| n.include?("Pixel Forge 1") }
      last_priced = names.rindex { |n| !n.include?("Pixel Forge") }
      assert forge_at > last_priced,
        "a price-less row must sort below every priced row on input #{dir}"
    end
  end

  test "index renders a price-less row as not-yet-tracked, never $0" do
    get root_url(modality: "image_generation")
    assert_response :success
    assert_select "tbody td", text: /Pixel Forge 1/
    assert_match(/not yet tracked/i, @response.body)
    # The price-less row must never read as a free model (scoped to its own row so
    # the native-priced "$0.04" sibling doesn't trip the guard).
    forge_one_row = css_select("tbody tr").find { |tr| tr.to_s.include?("Pixel Forge 1") }
    assert_no_match(/\$0\b/, forge_one_row.to_s)
  end

  test "show renders an honest not-yet-tracked note for a price-less directory row" do
    get model_url(ai_models(:image_gen))
    assert_response :success
    assert_select "h1", "Pixel Forge 1"
    assert_match(/not yet tracked/i, @response.body)
    assert_no_match(/\$0\b/, @response.body)
  end

  test "show renders a native-priced directory model by its unit, not three per-token cards" do
    get model_url(ai_models(:priced_image_gen))
    assert_response :success
    assert_select "h1", "Pixel Forge Pro"
    assert_match(/\$0\.04/, @response.body)
    assert_match(/image/i, @response.body)
    # No per-token cards (those would render an em-dash on NULL text rates).
    assert_select "p", text: /Input \/ 1M/, count: 0
    assert_select "p", text: /Output \/ 1M/, count: 0
    assert_no_match(/not yet tracked/i, @response.body)
    # The context window card stays.
    assert_select "p", text: /Context window/
  end

  test "show renders the three per-token cards for a text model unchanged" do
    get model_url(ai_models(:opus))
    assert_response :success
    assert_select "p", text: /Input \/ 1M/
    assert_select "p", text: /Output \/ 1M/
    assert_select "p", text: /Cached input \/ 1M/
  end

  test "index renders a native-priced directory row by its native unit, never a dash or zero" do
    get root_url(modality: "image_generation")
    assert_response :success
    assert_select "tbody td", text: /Pixel Forge Pro/
    # The native price spans the per-token columns as one cell, not three dashes.
    pro_row = css_select("tbody tr").find { |tr| tr.to_s.include?("Pixel Forge Pro") }
    assert pro_row, "the native-priced row should be listed"
    price_cell = pro_row.css("td.numeric[colspan='3']").first
    assert price_cell, "the price spans the three per-token columns as one cell"
    assert_equal "$0.04 / image", price_cell.text.strip
    assert_no_match(/not yet tracked/i, pro_row.to_s)
  end

  test "a native-priced directory row (no token rate) sinks below priced text rows on output desc" do
    get root_url(sort: "output", dir: "desc")
    assert_response :success
    names = css_select("tbody tr td .tp-model-name").map { |n| n.text.strip }
    pro_at = names.index { |n| n.include?("Pixel Forge Pro") }
    last_token_priced = names.rindex { |n| !n.include?("Pixel Forge") }
    assert pro_at, "the native-priced image-gen row should be listed"
    assert pro_at > last_token_priced,
      "a native-priced row with no token rate must sort below every token-priced row"
  end

  test "a native-priced directory row sinks below priced text rows on input in both directions" do
    %w[asc desc].each do |dir|
      get root_url(sort: "input", dir: dir)
      assert_response :success
      names = css_select("tbody tr td .tp-model-name").map { |n| n.text.strip }
      pro_at = names.index { |n| n.include?("Pixel Forge Pro") }
      last_token_priced = names.rindex { |n| !n.include?("Pixel Forge") }
      assert pro_at > last_token_priced,
        "a native-priced row must sort below every token-priced row on input #{dir}"
    end
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
