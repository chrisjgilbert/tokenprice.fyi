# Surfacing the morning digest: a `/news` feed + a homepage price-changes strip

The daily Slack message has two halves — a **news digest** (`NewsDigestJob`) and a
**price-moves digest** (`OpenRouter::SyncDigest`). Both carry data that lives
nowhere on the public site today. This plan brings them in as two surfaces, and
takes Compare out of the primary nav to keep the bar lean.

## Goals

1. A public **`/news`** page: the relevant-only headline stream, newest first,
   grouped by day — positioned as the *raw signal* that feeds the curated
   `/events` timeline.
2. A **"Recent price changes"** strip on the homepage, above the comparison
   table — the price-moves digest, on the page it's most at home.
3. Nav cleanup: drop **Compare** from the primary nav (keep the page + route),
   add **News**, preserve Compare's crawl path via a footer link.

## Non-goals (v1)

- No per-event deep links from news items (there's no `MarketEvent` show route;
  the "In Events" chip links to `/events`). Anchored deep links are a follow-up.
- No infinite scroll on `/news` (a cumulative `?page=` "Load more" is enough to
  start; the events infinite-scroll controller can be reused later).
- The strip renders on the root homepage only, not the `/embeddings` or
  `/image-generation` tabs.

---

## Positioning: `/news` vs `/events`

They are two stages of one pipeline, and the UI should say so rather than hide
one behind the other.

```
NewsScanJob → Haiku relevance filter      →  /news   (raw feed, links out)
            → EventCurationJob (Opus draft)
            → human approval               →  /events (curated record, first-party)
```

| | **/news** | **/events** |
|---|---|---|
| Stage | Machine-filtered signal | Human-approved record |
| Content | External headlines, link out | First-party entries + "so what" + citations + launches |
| Cadence | High-volume, daily, ephemeral | Low-volume, permanent, citable |
| Treatment | Compact link list | Rich timeline (nodes, rose rail) |

Make the relationship legible with: reciprocal cross-links, per-item "In Events"
chips, copy that names each page's job, and nav order `News · Events`
(raw → curated, left to right).

---

## Part A — `/news`

### A1. Model (`app/models/news_item.rb`)

`NewsItem` already exists with `relevant`, `kind` (`release`/`price`/`market`/`other`),
`rationale`, `published_at`, `url`, `source`, and an optional `market_event`.
Add one public scope:

```ruby
# The public feed: classified-relevant items with a publish date, newest first.
# Unclassified (relevant: nil) and irrelevant items never surface — only the
# digest funnel (pending_digest) tolerates nil.
scope :feed, -> { where(relevant: true).where.not(published_at: nil).order(published_at: :desc) }
```

### A2. Route (`config/routes.rb`)

```ruby
get "news", to: "news#index", as: :news
```

### A3. Controller (`app/controllers/news_controller.rb`)

Mirror `EventsController`'s conditional-GET discipline, but key freshness on the
news table (not the price catalog):

```ruby
class NewsController < ApplicationController
  PER_PAGE = 30

  def index
    @page = [ params[:page].to_i, 1 ].max

    return if catalog_fresh?(etag: [ :news, @page ],
                             last_modified: NewsItem.maximum(:updated_at))

    scope       = NewsItem.feed.includes(:market_event)
    @total      = scope.count
    @items      = scope.limit(@page * PER_PAGE).to_a
    @has_more   = @total > @items.size
    @next_page  = @page + 1
    @items_by_day = @items.group_by { |i| i.published_at.to_date }
  end
end
```

`catalog_fresh?` already accepts a `last_modified:` override
(`application_controller.rb:16`). `NewsItem.maximum(:updated_at)` re-uses the
`updated_at` column touched whenever an item is classified or attached to an event.

### A4. Views (`app/views/news/`)

- `index.html.erb` — header + subtitle, the funnel cross-link banner, then the
  day-grouped card. `content_for :title/:description/:canonical` and a
  `CollectionPage` JSON-LD block, mirroring `events/index.html.erb:1-13`.
- `_day_group.html.erb` — sticky day header (`fmt_date_full`) + `<ul>` of items.
- `_item.html.erb` — title (links to `item.url`, `target=_blank rel=noopener`),
  rationale, source label, kind badge, and the conditional "In Events" chip:

```erb
<% if item.market_event&.status == "published" %>
  <%= link_to "In Events →", events_path, class: "n-linked" %>
<% end %>
```

Kind badge only for `release`/`price`/`market` (reuse the `tp-badge tp-kind-*`
classes the events timeline already defines); `other`/`nil` → no badge.
Styles live in a page-scoped `<style>` block, as `events/index.html.erb` and
`models/index.html.erb` already do. The mockup's `.news-*` CSS is the starting point.

"Load more": when `@has_more`, a plain link to `news_path(page: @next_page)` that
re-renders cumulatively (no JS required).

### A5. Cross-links & discovery

- **Nav**: add News (see Part C).
- **`/events` → `/news`**: one line under the events subtitle —
  "Drawn from the daily news feed →" linking `news_path`
  (`events/index.html.erb`, in `.events-subtitle`).
- **Sitemap**: add `<url><loc><%= news_url %></loc>…` to
  `sitemaps/index.xml.erb`.
- **llms.txt** (optional): a "Latest AI pricing news" line in `pages/llms_txt.text.erb`.

---

## Part B — homepage "Recent price changes" strip

The Slack price-moves come from `OpenRouter::ModelSync::Result#repriced_records`,
computed live during a sync and never persisted as an entity. To surface them on
the web we derive them from persisted `PricePoint` history: **the step between a
model's two most-recent snapshots.**

### B1. Value object (`app/models/price_move.rb`)

A domain PORO, consistent with `PriceCatalog`/`ModelCategory`. Distinct from the
existing windowed `AiModel::PriceChange` (which measures vs a trailing window /
launch) — this one is a single dated step between consecutive snapshots.

```ruby
# One dated price step for one model: the move from its previous snapshot to its
# current one. `input`/`output`/`cached` are Deltas (or nil where unchanged);
# `headline` is the dimension shown on the strip's percent chip.
class PriceMove
  Delta = Data.define(:old, :new, :pct)

  DIMENSIONS = %i[input output cached].freeze  # cached = cached_input_per_mtok

  attr_reader :model_name, :model_slug, :provider_name, :provider_accent,
              :effective_on, :input, :output, :cached, :headline

  # built by AiModel#latest_move; see B2
end
```

`headline` picks the dimension to chip: input if it changed, else output, else
cached — with its `Delta`. Chip color: `pct >= 0` → up (rose), `< 0` → down
(emerald). The mockup labels non-input headlines ("▼ 75% cached").

### B2. Derivation on the record (`app/models/ai_model.rb`)

Keep the logic on the model that owns the price points, reusing the existing
`price_change_between` math:

```ruby
# The most recent price step: current snapshot vs the one before it, or nil when
# there's a single snapshot, nothing changed, or (with `within:`) the step is
# older than the window. Feeds the homepage "recent changes" strip.
def latest_move(within: nil)
  snaps = price_points.sort_by(&:effective_on)
  return nil if snaps.size < 2

  current, previous = snaps.last, snaps[-2]
  return nil if within && current.effective_on < Date.current - within

  PriceMove.build(self, from: previous, to: current)
end
```

`PriceMove.build` computes each `Delta` (skipping unchanged dimensions) and
returns `nil` if none of `DIMENSIONS` changed — so a re-confirmed price doesn't
show as a move.

### B3. Read seam (`app/models/price_catalog.rb`)

The read controllers go through `PriceCatalog`; add the collection there:

```ruby
# Recent price steps across the listed catalog, newest first — the homepage
# strip. `within` bounds staleness so a quiet week shows nothing rather than a
# month-old move.
def recent_price_moves(limit: 6, within: 30.days)
  AiModel.listed.includes(:provider, :price_points)
    .filter_map { |m| m.latest_move(within: within) }
    .sort_by(&:effective_on).reverse.first(limit)
end
```

### B4. View (`app/views/models/_recent_price_changes.html.erb`)

Rendered from `models/index.html.erb` **after the hero, before the "Price table"
section label**, and only on the root category:

```erb
<% if @category.root? && (moves = PriceCatalog.recent_price_moves).any? %>
  <%= render "models/recent_price_changes", moves: moves %>
<% end %>
```

(Confirm the exact `@category` root predicate against `ModelCategory`; the intent
is "the default language homepage only.") Each row: provider square
(`provider_accent`) + model name (links to `model_path`), the changed
dimension(s) as `old → new` in mono, and the headline percent chip. Header shows
the count and the latest `effective_on` (reusing the nav's live-dot convention).
No "see all" target in v1 (there's no `/changes` page); the strip stands alone.

**Freshness**: the homepage's existing `catalog_fresh?` etag already keys on
`PriceCatalog.last_modified` (max `PricePoint.updated_at`), which covers this
derived data — no caching change needed. The strip adds one `AiModel.listed`
load per full (non-304) render; acceptable, and can later share the load with
`@models` if it shows up in profiling.

---

## Part C — nav & Compare

`/compare` is the **engine** behind the table's inline compare (the dialog loads
it into a Turbo Frame — `models/index.html.erb:734`), the deep-link target of
each model page's CTA (`models/show.html.erb:89`), and an indexable SEO surface.
Keep the page and route; remove only the **nav link**, whose sole action is a
default Opus-vs-GPT view — a weaker entry point than "toggle compare, pick any two."

### C1. `app/helpers/application_helper.rb`

```ruby
def primary_nav_items
  [
    [ "Models", root_path,   -> { current_page?(root_path) } ],
    [ "Trends", trends_path, -> { current_page?(trends_path) } ],
    [ "News",   news_path,   -> { current_page?(news_path) } ],
    [ "Events", events_path, -> { events_active? } ]
  ]
end
```

Single source of truth for desktop bar + mobile drawer, so both update at once.

### C2. Footer (`app/views/layouts/application.html.erb`, `.tp-foot` ~line 140)

Add a Compare link beside Data sources / Contact / Mastodon — a sitewide
crawlable path to `/compare`, preserving its internal link equity without
cluttering the primary nav.

```erb
<%= link_to "Compare models", compare_path, style: "…same as siblings…" %>
```

Leave the sitemap and `llms.txt` Compare entries as-is.

---

## File-by-file

**New**
- `config/routes.rb` — `get "news"` (edit)
- `app/controllers/news_controller.rb`
- `app/views/news/index.html.erb`, `_day_group.html.erb`, `_item.html.erb`
- `app/models/price_move.rb`
- `app/views/models/_recent_price_changes.html.erb`
- `test/controllers/news_controller_test.rb`
- `test/models/price_move_test.rb`

**Edit**
- `app/models/news_item.rb` — `feed` scope
- `app/models/ai_model.rb` — `latest_move`
- `app/models/price_catalog.rb` — `recent_price_moves`
- `app/helpers/application_helper.rb` — nav items (−Compare, +News)
- `app/views/layouts/application.html.erb` — footer Compare link
- `app/views/models/index.html.erb` — render strip
- `app/views/events/index.html.erb` — reverse cross-link to /news
- `app/views/sitemaps/index.xml.erb` — news_url
- `app/views/pages/llms_txt.text.erb` — news line (optional)
- `test/models/news_item_test.rb`, `test/models/price_catalog_test.rb` — extend

---

## Tests

- **`NewsItem.feed`** — includes relevant+dated, excludes irrelevant and
  `relevant: nil` and null-`published_at`, orders newest first.
- **`NewsController#index`** — 200; renders relevant items grouped by day;
  irrelevant items absent; `?page=2` widens the window and `@has_more` flips;
  conditional GET returns 304 on a repeat with matching validators.
- **`AiModel#latest_move`** — nil for a single snapshot; nil when the last two
  snapshots match; builds Deltas for the changed dimensions only; honors
  `within:`; percent matches `price_change_between`.
- **`PriceCatalog.recent_price_moves`** — newest-first, respects `limit` and
  `within`, `[]` when the catalog is quiet.
- **Nav** — a view/controller assertion that the primary nav renders News and
  not Compare, and that `/compare` still routes and renders.
- **Strip** — `models#index` shows the strip when moves exist, omits it when none.
- Close with `/preflight` (RuboCop, Brakeman, bundler-audit, tests, seed replant).

Mirror new tests under `test/models` / `test/controllers` per house layout.
Credential-touching paths use `stub_admin_digest!` / `stub_anthropic_key!`.

---

## Sequencing

Two reviewable units, shippable independently:

1. **`/news`** (Part A) + the nav change (Part C) — the piece you care most about,
   plus the nav cleanup that makes room for it.
2. **Price-changes strip** (Part B) — self-contained; can follow once the feed lands.

---

## Open decisions

1. **Price-move color semantics** — increase = rose (red), decrease = emerald
   (green), i.e. "expensive is bad for the buyer." Opposite of a stock ticker.
   Confirm.
2. **Strip bounds** — `limit: 6`, `within: 30.days`, root homepage only. Adjust?
3. **News pagination** — cumulative `?page=` + "Load more" for v1, infinite
   scroll deferred. OK?
4. **"In Events" chip** — links to `/events` (no per-event anchor yet). Acceptable
   for v1, or hold the chip until anchored deep links exist?
5. **Naming** — `PriceMove` (dated step) vs the existing `AiModel::PriceChange`
   (windowed). Distinct on purpose; flag if the two names will confuse.
