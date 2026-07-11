# Consolidating Trends / News / Events

A follow-up to `NEWS_AND_PRICE_CHANGES_PLAN.md`. That plan added `/news` (the raw
headline feed) and the "Recent price changes" strip. In shipping, the strip
landed on `/news` rather than the homepage, and the primary nav grew to four
happenings-adjacent items: **Models · Trends · News · Events**.

A PM review found the four-item cluster carries one redundant surface. `/trends`
(a flagship-price-over-time chart) and `/news` (a chronological link feed) are
structurally distinct and both justified. The real overlap is **`/news` vs
`/events`** — a raw timeline and a curated timeline of the same happenings — and
a second, quieter one: the price-movement story is scattered across three pages
(currents on Models, deltas on News, long-run trajectory on Trends).

This plan makes three moves:

1. **Relocate the "Recent price changes" strip from `/news` to `/trends`.**
   Trends becomes the single price-movement home: the long-run frontier arc
   (chart) plus what repriced recently (strip).
2. **Fold `/news` under the Events section.** Events is the one primary
   "what's happening" destination; the raw feed becomes a secondary *view*
   reached through a shared sub-toggle, not a competing top-level nav item.
3. **Trim the primary nav 4 → 3** (Models · Trends · Events) and update the
   freshness/SEO seams that follow.

`/trends` is unchanged in substance — it's the strongest page in the cluster and
the model for the others. The work is all on News, Events, and the strip.

## Goals

1. One primary destination for happenings (Events), one for price movement over
   time (Trends). No two top-level pages that read as raw-vs-finished versions of
   each other.
2. The raw headline feed stays reachable (SEO equity + reader option preserved)
   but sits *under* Events rather than beside it.
3. Price movement consolidated: currents on `/models`, recent deltas + long-run
   trajectory both on `/trends`.
4. No regressions to conditional-GET freshness, the sitemap, or inbound links.

## Non-goals

- No change to the `/trends` chart itself, `FlagshipTrend`, or its backing
  tables.
- No change to the ingestion/classification pipeline (`NewsScanJob`,
  `EventCurationJob`, the `NewsItem` model, `PriceMove` derivation).
- No merge of the two controllers into one. `NewsController` and
  `EventsController` stay separate, thin, and standard — the consolidation is
  navigation + positioning, not a data-model merge.
- No new `/changes` page. The strip stands alone on Trends as it did on News.

---

## Pre-flight: the analytics gate

The recommended design **keeps** `/news` (demoted to a secondary view). If
analytics already show `/news` pageviews and return rate are near zero, prefer
the **aggressive variant** (below) instead: retire the public feed, 301 it to
`/events`, and keep `NewsItem` as the admin curation queue. Decide this once,
up front — it changes Move 2 only. Everything in Moves 1 and 3 is identical
either way. Absent data, ship the recommended (reversible) path.

---

## Move 1 — "Recent price changes" strip → Trends

Today the strip renders on `/news` from `app/views/news/_recent_price_changes.html.erb`,
fed by `NewsController#index` (`@recent_price_moves = PriceCatalog.recent_price_moves`).
Move it to Trends verbatim; the data derivation (`PriceMove`, `AiModel#latest_move`,
`PriceCatalog.recent_price_moves`) does not change.

### 1a. Controller (`app/controllers/trends_controller.rb`)

Load the moves alongside the trends. Freshness needs no change: the trends etag
already keys on `FlagshipTrend.last_modified`, which is
`max(PriceCatalog.last_modified, AiModel…, Provider…)` — and
`recent_price_moves` derives entirely from `PricePoint` (covered by
`PriceCatalog.last_modified`) and `AiModel`. So the strip can't go stale behind a
304.

```ruby
def show
  stamp = FlagshipTrend.last_modified
  return if catalog_fresh?(etag: [ :trends, Date.current, stamp ], last_modified: stamp)

  @trends = FlagshipTrend.all
  @recent_price_moves = PriceCatalog.recent_price_moves
end
```

### 1b. View

- **Move** `app/views/news/_recent_price_changes.html.erb` →
  `app/views/trends/_recent_price_changes.html.erb` (partial + its scoped
  `<style>` unchanged).
- Render it in `app/views/trends/show.html.erb`, **below the chart card, above
  the "The flagships, provider by provider" backing tables**. Rationale: the
  chart is the page's hero and answers the long-run question; the strip is the
  "and here's what moved recently" companion — it should not sit above and bury
  the chart the way it topped the News feed.

```erb
<% if @recent_price_moves&.any? %>
  <%= render "trends/recent_price_changes", moves: @recent_price_moves %>
<% end %>
```

### 1c. Bind the two on the page (copy)

The chart is **frontier launch prices** (frontier-tier models, priced at
release); the strip is **recent repricing across the whole catalog** (any tier,
any dimension). That's complementary, not contradictory, but say so in one line
so it doesn't read as two unrelated price widgets. Add a short section heading
above the strip, e.g. **"What moved recently"**, with a one-sentence lede:
"The chart tracks flagship launch prices; below is every tracked price change
across the catalog in the last 30 days." (Match the Trends subtitle register.)

### 1d. News loses the strip

Remove the strip render and its `@recent_price_moves` load from
`NewsController#index`. This sharpens `/news` to purely the headline feed, and
lets its freshness drop `PriceCatalog.last_modified` (the strip was the only
reason it was folded in):

```ruby
return if catalog_fresh?(etag: [ :news, @page ],
  last_modified: [ NewsItem.maximum(:updated_at), MarketEvent.maximum(:updated_at) ].compact.max)
```

Update the News header/subtitle copy (see Move 2), which currently opens with
"Recent tracked price changes across the catalog, plus…".

---

## Move 2 — Fold News under Events

**Recommended (reversible).** Keep `/news` as its own thin controller and page,
but present it as a secondary *view* of the Events section rather than a peer in
the primary nav. Readers land on Events (curated) by default and can switch to
the raw feed via a shared sub-toggle.

### 2a. A shared section sub-toggle

Both `/events` and `/news` render a small segmented control at the top of the
page body:

```
[ Curated ]  [ All headlines ]
   /events        /news
```

- On `/events` this sits **above** the existing kind filter (All / Market /
  Launches), which stays as a sub-filter of the curated view.
- On `/news` only the sub-toggle shows (the raw feed has its own kind badges
  inline; no kind filter).

Extract to `app/views/shared/_happenings_nav.html.erb` (a partial, per house
style — no new helper needed) taking the active view as a local. Reuse the
existing `.tp-seg` segmented-control styling the events kind filter already uses.

### 2b. Keep the section lit in the primary nav

`events_active?` should return true on `/news` too, so the (renamed) primary nav
item stays highlighted across both views:

```ruby
def events_active?
  current_page?(events_path) || request.path.start_with?("/events") || current_page?(news_path)
end
```

### 2c. Headers read as one section

- `/events` header stays "Market events", subtitle keeps its "Curated from the
  daily news feed" line (the raw feed is now the sibling tab, so this cross-link
  can point at the sub-toggle rather than read as a link to a separate area).
- `/news` header changes from "News" to something that reads as the raw view of
  the same section, e.g. **"All headlines"**, subtitle: "Every relevant headline
  we scan, unedited and newest first — the raw feed behind the curated timeline."
  The existing funnel banner pointing to Events becomes redundant with the
  sub-toggle; remove it.

### Aggressive variant (if the analytics gate says `/news` is dead)

- 301 `/news` (and any `?page=`) → `/events`, following the `/guide` redirect
  precedent in `routes.rb`.
- Drop `NewsController`, the `news/` views, the `news_url` sitemap and `llms.txt`
  entries.
- Keep `NewsItem`, its `feed`/`awaiting_curation` scopes, and the ingestion jobs
  — the feed becomes admin-only curation input, surfaced under `/admin` if a
  reviewer UI is wanted (out of scope here).
- Skip 2a–2c entirely; Move 3's nav trim still applies.

---

## Move 3 — Nav, sitemap, tests

### 3a. Primary nav (`app/helpers/application_helper.rb`)

Drop the News row; three items remain. Rename intent: "Events" now heads the
whole happenings section.

```ruby
def primary_nav_items
  [
    [ "Models", root_path,   -> { current_page?(root_path) } ],
    [ "Trends", trends_path, -> { current_page?(trends_path) } ],
    [ "Events", events_path, -> { events_active? } ]
  ]
end
```

Single source of truth for desktop bar + mobile drawer (both iterate it), so
both update together.

### 3b. Sitemap / llms.txt

- **Recommended path:** leave both `news_url` and `events_url` in
  `sitemaps/index.xml.erb` (both are still live, indexable URLs). Optionally drop
  `/news` priority from `0.8` → `0.6` to signal it's secondary.
- **Aggressive variant:** remove the `news_url` sitemap line and the `/news`
  `llms.txt` line; the 301 handles inbound crawl.

### 3c. Freshness recap

- **Trends** — no etag change; `FlagshipTrend.last_modified` already covers the
  moved strip.
- **News** — drop `PriceCatalog.last_modified` from its `last_modified` (the
  strip was its only price dependency). Keep `NewsItem` + `MarketEvent`.
- **Events** — unchanged.

---

## File-by-file

**Move / edit**
- `app/views/news/_recent_price_changes.html.erb` → `app/views/trends/_recent_price_changes.html.erb` (move)
- `app/controllers/trends_controller.rb` — load `@recent_price_moves`
- `app/views/trends/show.html.erb` — render strip below chart + binding copy
- `app/controllers/news_controller.rb` — drop strip load; simplify `last_modified`
- `app/views/news/index.html.erb` — new header/subtitle, drop strip render + funnel banner, add sub-toggle
- `app/views/events/index.html.erb` — add sub-toggle above kind filter
- `app/views/shared/_happenings_nav.html.erb` — **new** shared sub-toggle partial
- `app/helpers/application_helper.rb` — remove News nav row; extend `events_active?`
- `app/views/sitemaps/index.xml.erb` — (optional) lower `/news` priority

**Aggressive variant instead of the News edits above**
- `config/routes.rb` — `get "news", to: redirect("/events", status: 301)` (+ drop the `news#index` route)
- delete `app/controllers/news_controller.rb`, `app/views/news/*`
- `app/views/sitemaps/index.xml.erb`, `app/views/pages/llms_txt.text.erb` — drop `/news`

---

## Tests

- **`TrendsController#index`** — 200; renders the strip when moves exist, omits
  it when none; conditional GET still 304s on a repeat with matching validators
  after adding the strip.
- **`NewsController#index`** — still 200 and renders the feed; the strip is
  **absent**; the sub-toggle is present with "All headlines" active; 304 on a
  repeat. (Aggressive variant: assert `/news` 301s to `/events`.)
- **`EventsController#index`** — sub-toggle present with "Curated" active; kind
  filter unchanged.
- **Nav** — primary nav renders Models/Trends/Events and **not** News; the
  Events item stays active on `/news` (`events_active?`).
- **`PriceCatalog.recent_price_moves`** — unchanged; existing coverage stands.
- Existing `news_controller_test.rb` assertions that check for the price strip
  on `/news` must flip to asserting its absence (and its presence on `/trends`).
- Close with `/preflight` (RuboCop, Brakeman, bundler-audit, importmap audit,
  test suite, seed replant).

Mirror any new tests under `test/controllers` / `test/helpers` per house layout.
Credential-touching paths use `stub_admin_digest!` / `stub_anthropic_key!`.

---

## Sequencing

Two reviewable units, shippable independently:

1. **Move 1** — relocate the strip to Trends and strip it from News. Fully
   self-contained; delivers the price-movement consolidation on its own.
2. **Moves 2 + 3** — the IA fold and nav trim. Independent of Move 1; land it
   once the analytics gate is decided.

---

## Open decisions

1. **Analytics gate** — recommended (keep `/news` as a secondary view) vs
   aggressive (301 + admin-only queue). Decide from `/news` traffic before
   Move 2. Default: recommended.
2. **Strip placement on Trends** — below the chart, above the backing tables
   (recommended), vs directly under the header. Confirm.
3. **Section labels** — primary nav item "Events" heading a section whose raw
   view is titled "All headlines". Is "Events" still the right label for the
   section, or should it read "Timeline" / "Activity"? (Recommend leaving
   "Events" to preserve the established URL and nav muscle memory.)
4. **`/news` sitemap priority** — leave at `0.8` or lower to `0.6` to signal
   secondary. Recommend lower.
