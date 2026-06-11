# tokenprice.fyi

Track and compare the price of LLM API tokens — Claude, GPT, Gemini, Grok, DeepSeek — and
see how prices change over time.

It answers questions like:

- How much does Opus 4.8 cost vs GPT-5.5?
- How has the price of Sonnet changed?
- What's the cheapest frontier model right now?
- How has pricing moved this year?

## Stack

- **Rails 8** (Ruby 3.3), server-rendered ERB — fast and SEO-friendly.
- **SQLite** (Rails 8's production-grade setup) for storage.
- **Tailwind CSS** (`tailwindcss-rails`, standalone CLI — no Node build).
- **Solid Queue / Solid Cache / Solid Cable** — ready for the background jobs below.
- **Inline SVG charts** rendered server-side (`ChartsHelper`) — zero JS, no chart CDN dependency.

## Data model

Prices are stored as an **append-only dated history**, so a model's price over time is a
series of snapshots rather than a single number.

```
Provider ──< AiModel ──< PricePoint
  └ country, country_code      └ effective_on, input/output/cached $ per 1M tokens, source, note
```

Each `Provider` records the country its lab is headquartered in (`country` name +
`country_code`, an ISO 3166-1 alpha-2 code like `US`/`CN`/`FR`). The **Map** page
(`/map`) uses that code to shade a server-rendered SVG world map by how many providers
each country hosts — playing up the geopolitics of who builds the frontier. Per-country
cards rank the contenders with model counts and the **average** (and cheapest) I/O price
of their models. The map geometry is a static, equirectangular-projected dataset vendored
at `lib/data/world_map.json` (derived from Natural Earth 110m); `WorldMapHelper` loads it
and `Provider#flag_emoji` derives the flag from the country code.

The map stays true to the zero-JS house style: each country shape is a real `<a>` link
into the filtered price table (`/?providers[]=…`), so clicking a country works without
JavaScript. A small Stimulus controller (`map_controller.js`) layers a rich hover/focus
card on top as progressive enhancement — no map engine or tile CDN.

- `AiModel#current_price` — the most recent snapshot.
- `AiModel#launch_price` — the earliest snapshot.
- `AiModel#blended_per_mtok` — a single sortable figure at a 3:1 input:output mix.
- `AiModel#blended_change_since_launch` — % change from launch to now.

To **record a price change**, add a new `PricePoint` with a later `effective_on`. The launch
point stays, so the history chart draws the move. (See `db/seeds.rb` — DeepSeek V4's 75% cut
is a worked example.)

## Running locally

```bash
bin/setup            # installs gems, prepares the db, seeds, etc.
bin/dev              # starts Rails + the Tailwind watcher (http://localhost:3000)
```

Or step by step:

```bash
bin/rails db:prepare   # create + migrate
bin/rails db:seed      # load providers, models and price history
bin/rails server
```

## Tests

```bash
bin/rails test
```

Covers the pricing/blended-price domain logic and every public route.

## Updating prices

Curated prices live in `db/seeds.rb` (idempotent — safe to re-run). Edit a model's `prices:`
array to add a snapshot, then `bin/rails db:seed`.

## OpenRouter sync

A daily job (`OpenRouterSyncJob`, scheduled in `config/recurring.yml`) pulls
[OpenRouter's](https://openrouter.ai) public model catalogue and uses it as an automated
data source alongside the hand-curated catalogue and manual edits. It:

- **Augments** the list — adds models we don't already track (keyed by `AiModel#openrouter_id`),
  attaching them to the matching curated provider where one exists.
- **Never clobbers curated data** — a model that duplicates a curated one (same provider, same
  normalised name) is left to the curated record, and `source: "manual"` rows keep their
  hand-written metadata and authoritative price history.
- **Keeps history honest** — appends a new `PricePoint` (`source: "openrouter.ai"`) only when
  the price actually moved since the last snapshot.

The scheduled run fires in **production only** (like the other recurring jobs); locally, run it
on demand with `bin/rails openrouter:sync`. No API key is needed for the public models endpoint;
set `OPENROUTER_API_KEY` if you want authenticated requests. The mapping lives in
`app/services/open_router/` (`Client` fetches, `ModelSync` imports).

OpenRouter doesn't expose a capability tier, and price is a poor proxy for it, so imported models
land in a neutral `mid` tier for a human to re-curate — this also keeps a bulk import out of the
cheapest-frontier headline, which only ranks `frontier`-tier models.

To opt a curated model into automated price enrichment, set its `openrouter_id` (e.g. via the
admin) to the matching OpenRouter id — the sync will then append its price moves while leaving
the curated metadata untouched.

## Admin

A password-protected admin at `/admin` for adding/editing prices, models, and providers
by hand (e.g. when you read a new price online). Auth is a single shared password — its
bcrypt digest lives in encrypted credentials, verified in `Admin::SessionsController`.

Set the password once:

```bash
bin/rails 'admin:set_password[your-password]'   # writes admin_password_digest to credentials
```

Then sign in at `/admin/login`. In production, supply `RAILS_MASTER_KEY` so credentials
decrypt. The admin area is `noindex` and `Disallow`ed in robots.txt.

## Roadmap

The schema and Solid Queue are set up for where this is heading:

- **Scraper job** — the OpenRouter sync above is the first of these. More provider-specific
  sources (checking pricing pages directly) can append `PricePoint`s the same way.
- **Model-news context** — pull release announcements (e.g. "Opus 4.8 released") and surface
  them alongside the price timeline.
- Interactive charts (Chartkick/Chart.js or Inertia) once deployed somewhere with CDN access.

## Data accuracy

Anthropic figures are authoritative. Other providers are best-effort from public pricing pages
(as of June 2026) and may lag — each `PricePoint` records its `source`. Not affiliated with any
provider.
