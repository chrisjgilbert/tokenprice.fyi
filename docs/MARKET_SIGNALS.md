# Market signals — design for automated release & event detection

Status: **proposal, agreed direction — not yet built** (June 2026).

The goal is a notify-me pipeline, not an auto-publish one. Automation watches
for signals and emails a digest; a human stays the curator and turns the
worthwhile signals into `MarketEvent`s, `PricePoint`s, or new models via the
admin / seeds, exactly as today. Nothing here writes to the curated tables.

## Jobs to be done

1. **When a price we track changes, notify me** so I can research why.
2. **Periodically check for model releases** in news / blogs / provider sites.
3. **When the OpenRouter sync creates new models or providers, notify me.**
4. **Periodically search the news for AI stories** and judge whether they are
   pricing-relevant.

Decisions already made:

- **Notification channel: email via SMTP.** Action Mailer is present but
  unconfigured in production (`config/environments/production.rb` still has the
  placeholder). Wire up an SMTP provider (Resend/Postmark free tier is plenty
  at this volume), put credentials in encrypted credentials, deliver digests to
  the owner's address.
- **Relevance filtering: Claude classifier from day one** (jobs 2 and 4), via
  the official `anthropic` Ruby gem.

## Architecture

```
OpenRouterSyncJob ──(already runs daily)──┐
                                          ├─► SignalDigestMailer ──► inbox
ReleaseWatchJob  ──► news_items ──► Claude classifier ──┘
NewsScanJob      ──► news_items ──► Claude classifier ──┘
```

One new table, two new jobs, one mailer, and a small change to the existing
sync. All scheduled in `config/recurring.yml` (production-only, like the
existing jobs); failures surface through Honeybadger as usual.

### Jobs 1 + 3 — sync change digest (no new sources)

`OpenRouter::ModelSync` already classifies every catalogue row as
`created` / `repriced` / `enriched` / `skipped` but keeps only counts in its
`Result` struct. Extend `Result` to also collect the records:

- **repriced** — model, old → new input/output/cached, % blended change
- **created** — model name, provider, price, whether the provider is new

After the daily 6am run, `OpenRouterSyncJob` sends one digest email if anything
changed. Deduplication is inherent: the sync only appends a `PricePoint` when
the price actually moved, and a model is only `created` once. Curated models
linked via `openrouter_id` are covered too.

Email rows should link to the public model page and the admin edit page so the
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
  kind         string                              # "release" | "market" | "irrelevant"
  relevant     boolean                             # classifier verdict
  rationale    string                              # classifier's one-liner
  notified_at  datetime                            # set when included in a digest
```

This is working data, not curated data — safe to prune rows older than a few
months.

## The Claude classifier

Per candidate headline (title + source + first ~500 chars where available),
one Messages API call answering: *is this pricing-relevant for an LLM token
price tracker, and is it a model release, a price change, or other market
news?*

- **Gem:** `anthropic` (official Ruby SDK).
- **Model:** `claude-haiku-4-5` — at $1/$5 per MTok and ~200 input + ~50
  output tokens per headline, even 1,000 headlines/month costs well under $1.
- **Structured output:** constrain the response with
  `output_config: {format: {type: "json_schema", ...}}` to
  `{relevant: boolean, kind: "release"|"price"|"market"|"other", rationale: string}`
  so parsing never breaks on prose.
- **Key:** `ANTHROPIC_API_KEY` via Kamal secrets / encrypted credentials.
- **Failure mode:** if the API errors, mark the item unclassified and include
  it in the digest anyway (flagged) — never silently drop a candidate. The
  classifier is a noise filter, not a gatekeeper of record.

The classifier judges *relevance only*. It does not invent dates or prices,
and nothing it outputs is stored as fact in the curated tables — the human
verifies against the linked source before seeding, in keeping with the
verification discipline in `docs/SEED_PRICE_VERIFICATION.md`.

## Email digest

One mailer (`SignalDigestMailer`), three sections, sent only when non-empty:

1. **Price moves** (job 1) — model, old → new, % change, links.
2. **New models / providers** (job 3) — grouped by provider.
3. **News** (jobs 2 + 4) — release vs market sections, title + link +
   classifier rationale.

The sync digest fires right after the daily sync; the news jobs append to a
shared "pending" pool (`notified_at IS NULL`) flushed by the same daily send,
so the owner gets at most one email a day unless a sync-detected price move
warrants the immediate one.

## Build order

1. **SMTP + mailer plumbing** — pick a provider, add credentials, set
   `default_url_options` to the real host, smoke-test a delivery.
2. **Jobs 1 + 3** — extend `ModelSync::Result`, send the sync digest. No new
   tables; ships value immediately.
3. **`news_items` + classifier + `ReleaseWatchJob`** (job 2) — feeds first,
   page-diff fallbacks second.
4. **`NewsScanJob`** (job 4) — HN Algolia, reusing everything from step 3.

## Out of scope (deliberately)

- Auto-creating `MarketEvent`s or `PricePoint`s from news. Revisit only if
  digest triage becomes tedious; the natural extension is a draft/approve
  status on `MarketEvent` plus an admin review queue.
- Wayback/date verification — stays manual per `docs/NEXT_STEPS.md`.
- Scraping providers that prohibit it; the source allowlist sticks to feeds,
  public news indexes, and APIs (HN Algolia) intended for this use.
