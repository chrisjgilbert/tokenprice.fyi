# Market signals — design for automated release & event detection

Status: **proposal, agreed direction — not yet built** (June 2026).

Automation watches for signals, notifies the owner, and drafts candidate
`MarketEvent`s — but a human approves everything before it appears on the
site. Nothing automated writes *published* rows to the curated tables.

## Jobs to be done

1. **When a price we track changes, notify me** so I can research why.
2. **Periodically check for model releases** in news / blogs / provider sites.
3. **When the OpenRouter sync creates new models or providers, notify me.**
4. **Periodically search the news for AI stories** and judge whether they are
   pricing-relevant.

Plus: **LLM-assisted curation** — Claude drafts `MarketEvent` title/note pairs
in the house style from the signals above; the owner approves, edits, or
discards them in the admin.

Decisions already made:

- **Notification channel: Slack incoming webhook** (easier than email — no
  SMTP provider to set up; one webhook URL in Kamal secrets, one HTTP POST,
  Block Kit formatting for the digest). Email via SMTP stays on the table as
  a later addition if Slack proves too ephemeral for triage.
- **LLM filtering and drafting from day one.** Relevance classification uses
  an OpenAI mini-tier model (cheapest adequate option); event drafting uses
  Claude Opus (judgment + house-style writing). Each via its official Ruby
  gem.

## Architecture

```
OpenRouterSyncJob ──(already runs daily)──────────────┐
                                                      ├─► SlackNotifier ─► #channel
ReleaseWatchJob ──► news_items ─► mini classifier  ──┤
NewsScanJob     ──► news_items ─► mini classifier  ──┤
                                        │             │
                                        ▼             │
                          EventCurationJob (Claude) ──┘
                                        │ drafts
                                        ▼
                         market_events (status: draft)
                                        │ human approves in /admin
                                        ▼
                         market_events (status: published) ─► Trends overlay
```

One new table (`news_items`), three new jobs, a Slack notifier, schema
additions to `market_events`, and an admin review queue. All scheduled in
`config/recurring.yml` (production-only, like the existing jobs); failures
surface through Honeybadger as usual.

### Jobs 1 + 3 — sync change digest (no new sources)

`OpenRouter::ModelSync` already classifies every catalogue row as
`created` / `repriced` / `enriched` / `skipped` but keeps only counts in its
`Result` struct. Extend `Result` to also collect the records:

- **repriced** — model, old → new input/output/cached, % blended change
- **created** — model name, provider, price, whether the provider is new

After the daily 6am run, `OpenRouterSyncJob` posts one Slack message if
anything changed. Deduplication is inherent: the sync only appends a
`PricePoint` when the price actually moved, and a model is only `created`
once. Curated models linked via `openrouter_id` are covered too.

Each line links to the public model page and the admin edit page so the
"research why" loop is one click.

### Job 2 — `ReleaseWatchJob` (provider news feeds)

Polls an allowlist of provider feeds every ~6 hours:

- **RSS/Atom where available** (OpenAI news, Google blogs, Mistral, Meta AI,
  etc.) — parse with Ruby's bundled `rss` library, no new gem.
- **HTML page-diff fallback** for providers without feeds (Anthropic news,
  DeepSeek, Moonshot): fetch the news index page, extract article links,
  treat unseen URLs as new entries. More fragile — expect occasional
  selector maintenance.

Each new entry is stored in `news_items` (unique on URL — this is what
prevents re-notification), then classified (below). Relevant items join the
next digest with title, source link, and the classifier's one-line rationale.

Source list lives in a constant or small YAML so adding/removing a feed is a
one-line change.

### Job 4 — `NewsScanJob` (broader news search)

Daily. Backbone is the **Hacker News Algolia API** (free, no key, JSON):
query provider and model-family names — derived from our own `providers` /
`ai_models` tables so the queries track the catalogue — with a points
threshold to cut noise. Optionally add Google News RSS queries later for
breadth. Candidates flow through the same `news_items` dedupe + classifier +
digest path as job 2.

### `news_items` table

```
news_items
  url          string, null: false, unique index   # the dedupe key
  title        string, null: false
  source       string, null: false                 # "openai.com/news", "hn", ...
  published_at datetime
  kind         string                              # "release" | "price" | "market" | "other"
  relevant     boolean                             # classifier verdict
  rationale    string                              # classifier's one-liner
  notified_at  datetime                            # set when included in a digest
  market_event_id integer                          # set when curation drafted an event from it
```

This is working data, not curated data — safe to prune irrelevant rows older
than a few months.

## LLM stage 1 — the relevance classifier (OpenAI mini)

Per candidate headline (title + source + first ~500 chars where available),
one API call answering: *is this pricing-relevant for an LLM token price
tracker, and is it a model release, a price change, or other market news?*

- **Gem:** `openai` (official Ruby SDK).
- **Model:** the current cheapest OpenAI mini-tier model (GPT-5 mini at time
  of writing — check the live rate on tokenprice.fyi itself before wiring it
  in). At mini-tier pricing and ~200 input + ~50 output tokens per headline,
  1,000 headlines/month costs pennies. (Claude Haiku would also be well under
  $1/month at this volume — the saving is real but tiny; mini was chosen as
  the cheapest adequate option.)
- **Structured output:** constrain the response with a `json_schema` response
  format to
  `{relevant: boolean, kind: "release"|"price"|"market"|"other", rationale: string}`
  so parsing never breaks on prose.
- **Key:** `OPENAI_API_KEY` via Kamal secrets / encrypted credentials.
- **Failure mode:** if the API errors, mark the item unclassified and include
  it in the digest anyway (flagged) — never silently drop a candidate. The
  classifier is a noise filter, not a gatekeeper of record.

Note this makes the pipeline two-vendor (OpenAI for filtering, Anthropic for
drafting), i.e. two keys and two gems. If minimising dependencies later
matters more than the per-headline price, consolidating both stages onto one
provider is a one-class change — the classifier is deliberately a thin
wrapper.

## LLM stage 2 — the curation pipeline (`EventCurationJob`, Claude)

Runs weekly (or on demand from the admin). Takes the week's relevant
`news_items` plus sync-detected price moves and asks Claude to draft
`MarketEvent` candidates:

- **Input context:** the candidate signals (titles, sources, dates, price
  deltas), the current `MarketEvent` list and recent `released_on` dates (for
  dedup — "Opus gets 67% cheaper" must not be drafted twice), and a handful
  of existing seeded events as style few-shots (the seeds in `db/seeds.rb`
  have a very consistent editorial voice: punchy ~5-word title, one-sentence
  note with concrete figures).
- **Model:** `claude-opus-4-8` — this is judgment + writing, not bulk
  filtering, and the volume is a few events a week, so cost is negligible.
- **Output (structured):** zero or more drafts, each
  `{title, note, event_date, source_url, confidence, news_item_ids}`.
  Drafting *nothing* is a valid and common outcome — most weeks are quiet.
- **What it writes:** `MarketEvent` rows with `status: "draft"`, never
  published ones. Dates and figures in a draft are *claims to verify against
  the linked source*, not facts — same discipline as
  `docs/SEED_PRICE_VERIFICATION.md`. The admin review screen shows the source
  link next to every draft for exactly this reason.
- Drafts are announced in the Slack digest with a link to the review queue.

### `market_events` schema additions

```
status      string, default "published", null: false   # "draft" | "published"
source      string                                      # "seed" | "admin" | "curation"
source_url  string                                      # the announcement the event is based on
```

- Existing seeded rows default to `published`; `db/seeds.rb` keeps working
  unchanged.
- Every public read path scopes to published: `EventsHelper#build_all_events`,
  `TrendsController`, and the `chronological` / `recent_first` scopes get a
  `published` scope applied at the call sites (or baked into a
  `MarketEvent.listed` scope to mirror `AiModel.listed`).

### Admin review queue

`Admin::MarketEventsController` (the admin currently covers models, prices,
providers — market events are admin-less today, which is worth fixing
regardless):

- Index split into **drafts** (review queue) and **published**.
- Per draft: edit title/note/date inline, open the source URL, then
  **publish** or **discard**. Publishing flips `status`; discarding deletes
  the row and marks the `news_items` so the same story isn't re-drafted.
- Also gives the owner plain CRUD for hand-written events without touching
  seeds.

## Slack digest

One notifier (`SlackNotifier`, a thin `Net::HTTP` POST to the webhook URL —
no gem needed), used by all jobs. Message sections, posted only when
non-empty:

1. **Price moves** (job 1) — model, old → new, % change, links.
2. **New models / providers** (job 3) — grouped by provider.
3. **News** (jobs 2 + 4) — release vs market sections, title + link +
   classifier rationale.
4. **Drafted events** (curation) — title + link to the admin review queue.

The sync digest posts right after the daily sync; the news jobs append to a
shared "pending" pool (`notified_at IS NULL`) flushed by the same daily post,
so the default is one Slack message a day.

## Build order

1. **`SlackNotifier` + jobs 1 + 3** — webhook URL into Kamal secrets, extend
   `ModelSync::Result`, post the sync digest. No new tables; ships value
   immediately.
2. **`news_items` + classifier + `ReleaseWatchJob`** (job 2) — feeds first,
   page-diff fallbacks second.
3. **`NewsScanJob`** (job 4) — HN Algolia, reusing everything from step 2.
4. **Curation** — `market_events` migration (status/source/source_url),
   scope public reads to published, `Admin::MarketEventsController` review
   queue, then `EventCurationJob`.

Steps 1–3 are useful on their own even if curation waits; step 4's admin CRUD
is useful even before the curation job exists.

## Out of scope (deliberately)

- Auto-*publishing* events or auto-creating `PricePoint`s — every published
  fact passes through the human review queue.
- Wayback/date verification — stays manual per `docs/NEXT_STEPS.md`.
- Email/SMTP — dropped in favour of Slack for now; revisit if Slack triage
  proves too ephemeral.
- Scraping providers that prohibit it; the source allowlist sticks to feeds,
  public news indexes, and APIs (HN Algolia) intended for this use.
