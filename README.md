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
                            └ effective_on, input/output/cached $ per 1M tokens, source, note
```

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

For now, prices live in `db/seeds.rb` (idempotent — safe to re-run). Edit a model's `prices:`
array to add a snapshot, then `bin/rails db:seed`.

## Roadmap

The schema and Solid Queue are set up for where this is heading:

- **Scraper job** — a recurring Active Job (see `config/recurring.yml`) that checks provider
  pricing pages and appends a `PricePoint` when something changes.
- **Model-news context** — pull release announcements (e.g. "Opus 4.8 released") and surface
  them alongside the price timeline.
- Interactive charts (Chartkick/Chart.js or Inertia) once deployed somewhere with CDN access.

## Data accuracy

Anthropic figures are authoritative. Other providers are best-effort from public pricing pages
(as of June 2026) and may lag — each `PricePoint` records its `source`. Not affiliated with any
provider.
