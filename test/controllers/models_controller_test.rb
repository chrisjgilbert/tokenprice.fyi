require "test_helper"

class ModelsControllerTest < ActionDispatch::IntegrationTest
  test "index lists models with the cheapest-frontier callout" do
    get root_url
    assert_response :success
    assert_select "h1", /LLM API pricing, tracked from launch/
    assert_select "tbody td", /Claude Opus 4.8/
  end

  test "hero is the price-index hero with a pricing-explainer CTA and a trends CTA" do
    get root_url
    assert_response :success
    # Primary CTA into the pricing explainer.
    assert_select ".hero-cta a[href=?]", how_pricing_works_path, text: /How pricing works/
    # Secondary CTA into the flagship price-trends chart.
    assert_select ".hero-cta a[href=?]", trends_path, text: /Flagship prices over time/
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

  test "latest-events widget is present and the market-event timeline strip is gone" do
    get root_url
    assert_response :success
    assert_select ".hero-card-tag", /Latest events/
    # Dropped per audit #6: the thin, redundant market-event strip.
    assert_select ".hero-timeline", count: 0
    assert_select ".hero-card", text: /Recent activity/, count: 0
  end

  test "hero card has exactly one primary call to action" do
    get root_url
    assert_response :success
    # The CTA always links to the events timeline; there is exactly one.
    assert_select ".hero-card a.tp-btn", count: 1
  end

  test "hero renders a mini-timeline of several recent events, not just one" do
    get root_url
    assert_response :success
    # Several fixture models have distinct released_on dates, so the hero's
    # mini-timeline should surface more than a single launch chip — no
    # one-per-kind cap picking a single "winner".
    assert_select ".hero-card .hero-card-kind-chip.launch" do |chips|
      assert_operator chips.size, :>, 1
    end
  end

  test "hero CTA always routes to the events timeline" do
    # A market event newer than every fixture release becomes the primary
    # (model-less) event; the CTA should still route to /events regardless.
    MarketEvent.create!(title: "Newest market event", event_date: Date.new(2026, 6, 10),
                        kind: "market", status: "published", note: "A note.")

    get root_url
    assert_response :success
    assert_select ".hero-card a.tp-btn[href=?]", events_path, text: /View timeline/
  end

  test "hero shows only market events and launches — no reprice chips, and there is no ticker" do
    # Without a MarketEvent in the DB this test's market-chip check would pass
    # trivially off launch chips alone — no fixture file exists for the table,
    # so create one directly to exercise the market side of the assertion.
    MarketEvent.create!(title: "Test market event", event_date: Date.current,
                        kind: "market", status: "published", note: "A note.")

    get root_url
    assert_response :success
    # The hero card focuses on market events and model releases; price changes
    # are no longer surfaced as events anywhere, so no reprice chips and no
    # ticker banner.
    assert_select ".hero-card .hero-card-kind-chip.reprice", count: 0
    assert_select ".tp-ticker", count: 0
    assert_select ".hero-card .hero-card-kind-chip.launch"
    assert_select ".hero-card .hero-card-kind-chip.market"
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

  test "the homepage table has no price-change column" do
    get root_url
    assert_response :success
    assert_select "th", text: /Δ input/i, count: 0
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
    assert_select "thead a[data-turbo-frame=models]", count: 6
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

  test "index only offers modality facets present among the current category" do
    get root_url
    assert_response :success
    # The language tab offers the classes its listed rows have — text and the
    # multimodal sonnet — but not image_generation (now its own tab) nor a class
    # no listed row has (video_generation).
    assert_select "input[value=multimodal][name=?]", "modality[]"
    assert_select "input[value=image_generation][name=?]", "modality[]", count: 0
    assert_select "input[value=video_generation][name=?]", "modality[]", count: 0
  end

  test "the index renders a category tab strip with all three families and their counts, language active" do
    get root_url
    assert_response :success
    assert_select ".tp-tabs .tp-tab", count: 3
    assert_select ".tp-tabs .tp-tab", text: /Language models/
    assert_select ".tp-tabs .tp-tab", text: /Embeddings/
    assert_select ".tp-tabs .tp-tab", text: /Image generation/
    # The current tab is the language one and carries aria-current.
    assert_select ".tp-tabs .tp-tab[aria-current=page]", text: /Language models/
    language = ModelCategory.for("language")
    language_count = AiModel.listed.count { |m| language.member?(m.modality_class) }
    assert_select ".tp-tabs .tp-tab[aria-current=page] .tp-tab-count", text: language_count.to_s
  end

  test "the image tab swaps in a Pricing column and drops the per-token headers" do
    get image_generation_url
    assert_response :success
    assert_select "thead th", text: /Pricing/
    assert_select "thead th", text: %r{Input /1M}, count: 0
    assert_select "thead th", text: /Context/, count: 0
    # The image tab is the current page.
    assert_select ".tp-tabs .tp-tab[aria-current=page]", text: /Image generation/
    # A natively-priced image row shows its curated per-image summary.
    assert_select "tbody td", text: %r{\$0\.04 / image}
  end

  test "the language tab keeps the per-token headers and has no Pricing column" do
    get root_url
    assert_response :success
    assert_select "thead th", text: %r{Input /1M}
    assert_select "thead th", text: /Pricing/, count: 0
  end

  test "image-tab sort links stay on the image path and sorting by name returns 200" do
    get image_generation_url
    assert_response :success
    # Every sortable header links back to the image path, not the root tab.
    assert_select "thead a[href*=?]", "/image-generation"
    assert_select "thead a[href*='sort=provider'][href*='/image-generation']"

    get image_generation_url(sort: "name", dir: "asc")
    assert_response :success
    assert_select "tbody td", text: /Test Image Model/
  end

  test "the image tab hides the tier facet but keeps search and provider facets" do
    get image_generation_url
    assert_response :success
    assert_select ".tp-facet-chip-label", text: "Tier", count: 0
    assert_select ".tp-search input#q", count: 1
    assert_select ".tp-facet-chip-label", text: "Provider"
  end

  test "the image tab lists image-generation models" do
    get image_generation_url
    assert_response :success
    assert_select "tbody td", text: /Test Image Model/
    # Text and multimodal rows live on the language tab, not here.
    assert_select "tbody td", text: /DeepSeek V4 Pro/, count: 0
    assert_select "tbody td", text: /Guide Sonnet Fixture/, count: 0
  end

  test "the image tab shows a directory listing's price as not yet tracked, never a dash or $0" do
    get image_generation_url
    assert_response :success
    assert_select "td.tp-price-untracked", text: /not yet tracked/i
  end

  test "the image tab renders a natively-priced image row's price summary, not the untracked note" do
    get image_generation_url
    assert_response :success
    # The curated per-image price shows as a real value in the row.
    assert_select "td", text: /\$0\.04 \/ image/
    assert_select "td:match('class', ?)", /tp-price-untracked/, text: /\$0\.04 \/ image/, count: 0
  end

  test "the image tab still shows a price-less image row as not yet tracked" do
    get image_generation_url
    assert_response :success
    assert_select "td.tp-price-untracked", text: /not yet tracked/i
  end

  test "the language tab (root) excludes image-generation and embedding models" do
    get root_url
    assert_response :success
    assert_select "tbody td", text: /Claude Opus 4.8/
    assert_select "tbody td", text: /Guide Sonnet Fixture/
    # Image-generation and embedding rows moved to their own tabs.
    assert_select "tbody td", text: /Test Image Model/, count: 0
    assert_select "tbody td", text: /Test Priced Image Model/, count: 0
    assert_select "tbody td", text: /Test Embedding Model/, count: 0
  end

  test "the embeddings tab lists embedding models with an input and dimensions column, no output or pricing" do
    get embeddings_url
    assert_response :success
    # The input-only embedding row lists here, priced per input token.
    assert_select "tbody td", text: /Test Embedding Model/
    assert_select "thead th", text: %r{Input /1M}
    assert_select "thead th", text: /Dimensions/
    # Embeddings have no output/cached rate and no native pricing column.
    assert_select "thead th", text: %r{Output /1M}, count: 0
    assert_select "thead th", text: /Pricing/, count: 0
    # Its vector dimensions render in the row.
    assert_select "tbody td", text: /1536/
    # Text and image rows live on their own tabs, not here.
    assert_select "tbody td", text: /Claude Opus 4.8/, count: 0
    assert_select "tbody td", text: /Test Image Model/, count: 0
    # The embeddings tab is the current page.
    assert_select ".tp-tabs .tp-tab[aria-current=page]", text: /Embeddings/
  end

  test "the embeddings tab canonicalizes to its own path and carries embedding SEO" do
    get embeddings_url
    assert_response :success
    assert_select "link[rel=canonical][href=?]", embeddings_url
    assert_select "title", /embedding/i
    assert_select "meta[name=description][content*=?]", "input token"
  end

  test "the embeddings tab hides the tier facet but keeps search and provider facets" do
    get embeddings_url
    assert_response :success
    assert_select ".tp-facet-chip-label", text: "Tier", count: 0
    assert_select ".tp-search input#q", count: 1
    assert_select ".tp-facet-chip-label", text: "Provider"
  end

  test "embeddings-tab sort links stay on the embeddings path and default to cheapest input" do
    get embeddings_url
    assert_response :success
    assert_select "thead a[href*=?]", "/embeddings"
    # Default is cheapest input first, so no sort/dir ride in the filter form.
    assert_select "input[type=hidden][name=sort]", count: 0

    get embeddings_url(sort: "input", dir: "asc")
    assert_response :success
    assert_select "tbody td", text: /Test Embedding Model/
  end

  test "a stale modality param outside the current tab is ignored, not a dead empty table" do
    # /?modality=image_generation used to list image rows; they now have their own
    # tab. On the language tab that modality doesn't apply, so it's dropped rather
    # than filtering every language row out into a 'no models match' state.
    get root_url(modality: "image_generation")
    assert_response :success
    assert_select "tbody td", text: /Claude Opus 4.8/
    assert_select "td", text: /No models match your filters/, count: 0
  end

  test "the result count denominator is the current tab's total, not the whole catalog" do
    get root_url
    assert_response :success
    language_total = AiModel.listed.count { |m| ModelCategory.for("language").member?(m.modality_class) }
    assert_operator language_total, :<, AiModel.listed.count, "fixtures must include image rows for this to be meaningful"
    assert_select ".result-count", text: /of #{language_total}\b/
  end

  test "the image tab canonicalizes to the image path and carries image-specific SEO" do
    get image_generation_url
    assert_response :success
    assert_select "link[rel=canonical][href=?]", image_generation_url
    assert_select "title", /Image generation/
    assert_select "meta[name=description][content*=?]", "per image"
  end

  test "the image tab sorts by name and falls back to its default for a token-price sort" do
    get image_generation_url(sort: "name", dir: "asc")
    assert_response :success
    assert_select "tbody td", text: /Test Image Model/

    # "input" is a language-only sort; on the image tab it is not offered, so it
    # falls back to the category default rather than erroring.
    get image_generation_url(sort: "input")
    assert_response :success
    assert_select "tbody td", text: /Test Image Model/
  end

  test "the language and image tabs do not share a conditional-GET cache key" do
    get root_url
    assert_response :success
    language_etag = @response.headers["ETag"]

    get image_generation_url
    assert_response :success
    image_etag = @response.headers["ETag"]

    assert_not_equal language_etag, image_etag,
      "category tabs must not collide on one conditional-GET cache key"
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

  test "show renders a directory listing with a not-yet-tracked note and no price history" do
    get model_url(ai_models(:image_gen))
    assert_response :success
    assert_select ".tp-modality-badge", text: "Image generation"
    assert_select "p", text: /Priced per image — not yet tracked/
    # No per-token price cards and no price-history section for a price-less row.
    assert_select "h2", text: "Price history", count: 0
  end

  test "show meta description reflects a native-priced image model, not empty token prices" do
    get model_url(ai_models(:image_priced))
    assert_response :success
    # The directory_listing? re-key must not drop these rows to the per-token
    # description branch, which would emit "— input / — output per 1M tokens".
    assert_select "meta[name=description]" do |tags|
      content = tags.first["content"]
      assert_includes content, "$0.04 / image"
      assert_not_includes content, "per 1M tokens"
      assert_not_includes content, "—"
    end
  end

  test "show renders a natively-priced image model with its price summary, label and source, but no price history" do
    model = ai_models(:image_priced)
    get model_url(model)
    assert_response :success
    assert_select "*", text: /\$0\.04 \/ image/
    assert_select "*", text: /Per image/
    assert_select "*", text: /example\.com\/pricing/
    # A curated native price still isn't a per-token history.
    assert_select "h2", text: "Price history", count: 0
    assert_select "p", text: /Priced per image — not yet tracked/, count: 0
  end

  test "show renders a model and its price history chart" do
    get model_url(ai_models(:deepseek_v4))
    assert_response :success
    assert_select "h1", "DeepSeek V4 Pro"
    assert_select "svg"
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

  test "show stamps when the model data was last updated" do
    model = ai_models(:opus)
    get model_url(model)
    assert_response :success
    freshness = [ model.current_price&.updated_at, model.updated_at ].compact.max
    assert_select "time[datetime=?]", freshness.iso8601, text: /Data updated/
  end

  test "show offers a report link prefilled with the model context" do
    model = ai_models(:opus)
    get model_url(model)
    assert_response :success
    assert_select "a[href^=?]", "mailto:#{ApplicationHelper::REPORT_EMAIL}", text: "Report a problem" do
      assert_select ":match('href', ?)", "data%20issue%3A%20#{ERB::Util.url_encode(model.name)}"
    end
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

    all_ld = @response.body.scan(/<script type="application\/ld\+json">(.+?)<\/script>/m).map(&:first)
    json_ld = all_ld.find { |s| s.include?('"Product"') }
    assert json_ld, "expected Product JSON-LD on the show page"
    # input + output only (cached dropped) → offerCount 2.
    assert_includes json_ld, "\"offerCount\":2"
    # The dropped cached component must not appear at all in the breakdown.
    assert_not_includes json_ld, "cached input"
    # No em-dash placeholder for a nil price value in the breakdown text.
    assert_not_includes json_ld, "input —"
    assert_not_includes json_ld, "—\""
  end

  test "show renders the three per-token cards for a text model unchanged" do
    get model_url(ai_models(:opus))
    assert_response :success
    assert_select "p", text: /Input \/ 1M/
    assert_select "p", text: /Output \/ 1M/
    assert_select "p", text: /Cached input \/ 1M/
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
