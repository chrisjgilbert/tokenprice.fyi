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
2. **Retire the public `/news` feed.** It has essentially no traffic; 301 it to
   `/events`, delete the public page, and keep `NewsItem` + the ingestion jobs as
   the admin curation queue that already feeds Events.
3. **Trim the primary nav 4 → 3** (Models · Trends · Events) and update the
   freshness/SEO seams that follow.

`/trends` is unchanged in substance — it's the strongest page in the cluster and
the model for the others. The work is all on News, Events, and the strip.

## Goals

1. One primary destination for happenings (Events), one for price movement over
   time (Trends). No two top-level pages that read as raw-vs-finished versions of
   each other.
2. Inbound `/news` links and bookmarks land on the curated equivalent (Events),
   not a 404.
3. Price movement consolidated: currents on `/models`, recent deltas + long-run
   trajectory both on `/trends`.
4. No regressions to conditional-GET freshness, the sitemap, or inbound links.

## Non-goals

- No change to the `/trends` chart itself, `FlagshipTrend`, or its backing
  tables.
- No change to the ingestion/classification pipeline (`NewsScanJob`,
  `EventCurationJob`, the `NewsItem` model, `PriceMove` derivation). Only the
  public `/news` page is removed, not the machinery behind it.
- No new admin reviewer UI for the curation queue (a possible follow-up now that
  the feed has no public page).
- No new `/changes` page. The strip stands alone on Trends as it did on News.

---

## Decision: retire the public `/news` feed

**Resolved.** `/news` has had essentially no traffic since it shipped. There is
no reader audience to preserve, so the plan takes the **retire** path for Move 2:
301 `/news` → `/events`, delete the public controller/views, and keep `NewsItem`
plus the ingestion jobs as the admin curation queue that feeds Events. The
reversible "secondary view under Events" design is recorded below as the path
*not* taken, in case the decision is revisited.

Moves 1 and 3 are unaffected by this — they read the same either way.

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

The strip's only home is now `/trends`. Because `/news` is deleted wholesale in
Move 2, there's nothing to edit in `NewsController` — moving the partial out and
rendering it on Trends is the whole change. (`_recent_price_changes.html.erb`
is the one file under `news/` that survives the deletion, relocated to `trends/`.)

---

## Move 2 — Retire the public News feed

Per the decision above, `/news` is removed as a public surface and 301'd into
Events. The ingestion pipeline is untouched — it still runs, it just no longer
has a public page; its output is what Events curates from.

### 2a. Route (`config/routes.rb`)

Replace the `news#index` route with a 301 to `/events`, following the `/guide`
redirect precedent already in the file. A `?page=` query is dropped by the
redirect (fine — those were pagination of a feed that no longer exists).

```ruby
# The public raw news feed was retired (no traffic); its curated distillation
# lives at /events, and the ingestion pipeline still feeds it. 301 inbound
# links and bookmarks there.
get "news", to: redirect("/events", status: 301)
```

### 2b. Delete the public surface

- Delete `app/controllers/news_controller.rb`.
- Delete `app/views/news/` (`index.html.erb`, `_item.html.erb`; the
  `_recent_price_changes.html.erb` partial is **moved**, not deleted — see
  Move 1).
- Delete `test/controllers/news_controller_test.rb`.

### 2c. Keep the pipeline and the model

- `NewsItem`, its `feed` / `awaiting_curation` / `pending_digest` scopes, and the
  `NewsScanJob` / `EventCurationJob` / digest jobs all stay — they are the
  curation queue behind Events. (`feed` is now used only if a future admin
  reviewer UI wants it; leave it, it's harmless and tested.)
- A dedicated admin reviewer UI for the queue is **out of scope** here.

### 2d. Events cross-link cleanup

`/events` subtitle currently ends "Curated from the daily news feed →" linking
`news_path`. With `/news` now redirecting back to `/events`, that link would be a
self-link — remove the link. Keep the descriptive phrase (reworded so it doesn't
promise a clickable feed), e.g. "Curated from the headlines we scan each day."
Any other `news_path` references (the removed feed's "In Events" chip goes with
its view) — grep and clear.

### Path not taken — News as a secondary view under Events

Recorded for the record. Had `/news` shown real traffic, the reversible design
was: keep `NewsController` thin and unchanged, add a shared
`[ Curated ] [ All headlines ]` sub-toggle partial
(`app/views/shared/_happenings_nav.html.erb`) rendered on both `/events` and
`/news`, extend `events_active?` to light the nav on `/news`, and retitle the
News page "All headlines" as the raw view of the Events section. Not pursued.

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

Remove the `news_url` line from `sitemaps/index.xml.erb` and the `/news` line
from `pages/llms_txt.text.erb` (if present) — the URL now 301s, so it shouldn't
advertise itself as canonical. The 301 handles any inbound crawl.

### 3c. Freshness recap

- **Trends** — no etag change; `FlagshipTrend.last_modified` already covers the
  moved strip.
- **News** — gone (301).
- **Events** — unchanged.

---

## File-by-file

**Move 1 — strip to Trends**
- `app/views/news/_recent_price_changes.html.erb` → `app/views/trends/_recent_price_changes.html.erb` (move)
- `app/controllers/trends_controller.rb` — load `@recent_price_moves`
- `app/views/trends/show.html.erb` — render strip below chart + binding copy

**Move 2 — retire News**
- `config/routes.rb` — replace `news#index` with `redirect("/events", status: 301)`
- delete `app/controllers/news_controller.rb`
- delete `app/views/news/index.html.erb`, `app/views/news/_item.html.erb`
- delete `test/controllers/news_controller_test.rb`
- `app/views/events/index.html.erb` — drop the `news_path` cross-link, reword the subtitle
- `app/views/sitemaps/index.xml.erb` — drop the `news_url` line
- `app/views/pages/llms_txt.text.erb` — drop the `/news` line (if present)

**Move 3 — nav**
- `app/helpers/application_helper.rb` — remove the News nav row

---

## Tests

- **`TrendsController#index`** — 200; renders the strip when moves exist, omits
  it when none; conditional GET still 304s on a repeat with matching validators
  after adding the strip.
- **`/news` route** — asserts a 301 redirect to `/events` (add to the events or a
  routing test; `news_controller_test.rb` is deleted).
- **`EventsController#index`** — unchanged behaviour; assert the subtitle no
  longer emits a `news_path` link.
- **Nav** — primary nav renders Models/Trends/Events and **not** News.
- **`PriceCatalog.recent_price_moves`** — unchanged; existing coverage stands.
- **Sitemap** — assert `/news` is absent from the generated XML.
- Close with `/preflight` (RuboCop, Brakeman, bundler-audit, importmap audit,
  test suite, seed replant).

Mirror any new tests under `test/controllers` / `test/helpers` per house layout.
Credential-touching paths use `stub_admin_digest!` / `stub_anthropic_key!`.

---

## Sequencing

Two reviewable units, shippable independently:

1. **Move 1** — relocate the strip to Trends. Fully self-contained; delivers the
   price-movement consolidation on its own, and must land before (or with) Move 2
   so the `news/` partial has a new home before the directory is deleted.
2. **Moves 2 + 3** — retire `/news` and trim the nav. Independent otherwise.

---

## Open decisions

1. ~~**Analytics gate**~~ — **resolved**: `/news` has no traffic, so it's
   retired and 301'd to `/events` (see the Decision section).
2. **Strip placement on Trends** — below the chart, above the backing tables
   (recommended), vs directly under the header. Confirm.
3. **Events subtitle rewording** — with the `news_path` link gone, confirm the
   replacement phrase ("Curated from the headlines we scan each day").
