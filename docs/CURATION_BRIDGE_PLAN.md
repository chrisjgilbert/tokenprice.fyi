# Detection → curation bridge — plan

> Turn a detected model launch into a **reviewed catalog candidate**, so a new
> model (especially a provider-exclusive one that never hits OpenRouter, like
> Meta's Muse Spark) surfaces as a ready-to-approve seed row instead of sitting
> unnoticed in the news digest. Human-approved; never auto-published.

## The gap this closes

Two systems run today and don't talk to each other:

- **Detection (news):** `ReleaseWatchJob` (provider blogs + the new aggregator
  feeds) and `NewsScanJob` (HN) store launches as `news_items` and have Claude
  classify each — `kind: "release"` means *new model*. This already works and is
  modality-agnostic.
- **Catalog:** `AiModel` rows come from the OpenRouter sync (language long-tail)
  or hand-curated seeds (flagships + the directory categories).

Nothing bridges the two. A launch can be *detected* (Meta's blog RSS caught Muse
Spark) yet never *curated* — no automation turns "kind: release" into a priced
catalog row. A human reading the digest is the only bridge, and it's lossy.

## The precedent to mirror

This isn't a new pattern for the codebase — it's the twin of something that
already exists. `EventCurationJob` takes classified news items and curates them
into `MarketEvent` records (the `news_items.market_event_id` / `curated_at`
columns are exactly that bridge). The model bridge is the same shape with a
different target:

```
news_item (kind: "release")  --Claude extraction-->  CurationCandidate  --admin approve-->  AiModel (source: manual)
        ↑ already exists                                   ↑ new                                    ↑ existing admin flow
```

## Design

### 1. Trigger
A scheduled `ModelCurationJob` (thin wrapper, added to `config/recurring.yml`
after `release_watch`/`news_scan`) picks up `news_items` where `relevant == true`,
`kind == "release"`, and not yet processed. "Processed" is tracked with a nullable
`curated_for_model_at` timestamp (parallel to the existing `curated_at` used for
market events), so each release item is extracted at most once.

### 2. Extraction (operation object)
`NewsItem::ModelExtraction` — a noun-named operation reached via
`news_item.extract_model_candidate` (house style; mirrors
`NewsItem::Classification`). It fetches the article body and calls
`AnthropicClient.build` with a **structured tool schema** (same technique as the
classifier) to extract:

- `model_name`, `provider_name`
- `modality` → maps to a `ModelCategory` (language / embeddings / rerank / speech
  / tts / image / video)
- pricing in the category's native shape: per-token (`input`/`output`) for
  language/embeddings, or `pricing_model` + `price_summary` (or `native_price_usd`
  + unit) for a directory category
- `context_window`, `released_on`, `source_url`, and a **confidence** (H/M/L)

Confidence is load-bearing: the extractor is told to return **L and omit a price
when the article doesn't state one** rather than guess — the same "don't fabricate
a number" rule the pricing docs hold. A launch post that announces a model but
not its price yields a candidate with the model identity and a null price (→ a
"not yet tracked" directory row, or a held candidate for a per-token model).

### 3. Dedup
Skip when a model with that slug (`name.parameterize`) or a matching
name+provider already exists. An existing model whose *price* the article changes
is a different signal — route it to a "price-change" candidate (a later
extension; v1 just flags "already in catalog" and links the row).

### 4. Persistence + review surface
A `CurationCandidate` record holds the extracted fields, a generated **seed
snippet** (the `db/seeds.rb` hash, ready to paste), the source URL, confidence,
and a `status` (`pending` / `accepted` / `dismissed`). Surfaced in the admin
namespace as `admin/curation_candidates` — a review queue mirroring how
`admin/market_events` already works — with a **Slack nudge** (reusing
`SlackNotifier`, like the daily digest) when new H/M candidates land.

### 5. Approve
Accepting a candidate creates the `AiModel` row as `source: "manual"` — exactly
what `admin/models` does today — and displays the seed snippet + the
`docs/<CATEGORY>_MODEL_PRICING.md` line to add, so the human keeps `db/seeds.rb`
and the pricing doc (the source of truth per `docs/DATA_MAINTENANCE.md`) in sync.

## The one real design decision: seeds vs. live DB

`docs/DATA_MAINTENANCE.md` makes `db/seeds.rb` the source of truth, but
`admin/models` already writes rows straight to the prod DB. The bridge inherits
that tension. Three options:

- **(A, recommended for v1) Approve → create the manual row now + hand over the
  seed snippet.** Consistent with how `admin/models` already works; publishes
  immediately; the candidate retains the snippet so a human backfills
  `db/seeds.rb` + the pricing doc to make it durable. A `pricing:staleness`-style
  check could later flag "in DB but not in seeds" drift.
- **(B) Approve → open a draft PR editing `db/seeds.rb`.** Keeps seeds strictly
  authoritative, but needs a GitHub token in the app and is slower.
- **(C) Candidate queue only, no write.** The bridge just produces reviewed
  candidates + snippets; the human does the seeds edit + PR. Least automation,
  zero drift risk.

Recommendation: **A**, because it matches the existing admin write-path and keeps
a human in the loop, with the snippet making the seeds backfill a copy-paste. 
Revisit B once the volume justifies wiring GitHub into the app.

## Guardrails (the ethos, kept)

- **Never auto-publish.** Every candidate is reviewed; approval is a human click.
- **Confidence-gated.** L-confidence or price-less candidates are flagged, not
  hidden — surfaced as "identity found, price unconfirmed", never with a guessed
  number.
- **Sourced.** Every candidate carries the `source_url` the extraction read, so
  the reviewer verifies against a primary page before approving (the H/M/L
  discipline the whole directory rests on).

## Storage

A migration for `curation_candidates` (or, lighter, a set of columns on
`news_items` if we keep it 1:1 with the release item — but a separate table is
cleaner since one launch article can name several models). Plus the
`news_items.curated_for_model_at` timestamp for the idempotent trigger.

## TDD plan

Tests first, per phase:
1. **Trigger/idempotency** — `ModelCurationJob` processes only `relevant &&
   kind=="release"` items, and each item once (`curated_for_model_at` set). Stub
   the extractor.
2. **Extraction** — `NewsItem::ModelExtraction` maps the tool result to a
   `CurationCandidate`; a price-less article yields a candidate with null price +
   L confidence (no fabrication); the modality maps to the right `ModelCategory`.
   Stub `AnthropicClient` (as `stub_anthropic_key!` + a canned tool response).
3. **Dedup** — an article naming an existing model produces no new candidate (or
   a flagged "already in catalog" one), never a duplicate `AiModel`.
4. **Approve** — accepting a candidate creates one `source: "manual"` `AiModel`
   with the extracted fields; re-accepting is a no-op.
5. **Admin + Slack** — the review queue lists pending candidates; the nudge fires
   for new H/M candidates only.

## Ship order

1. Migration + `CurationCandidate` model + `NewsItem::ModelExtraction` operation
   (+ the tool schema). Tests.
2. `ModelCurationJob` + `recurring.yml` entry + the Slack nudge. Tests.
3. `admin/curation_candidates` review queue + approve action. Tests.

Then `/code-review --fix`, `/verify`, PR, merge on green — the usual rhythm.

## Explicitly out of scope for v1

- Price-*change* detection for existing models (the harder signal; the staleness
  report + Tier-2 re-verify job cover re-pricing separately).
- Auto-opening PRs (option B) — deferred until volume warrants GitHub creds.
- Fully automatic publishing — deliberately never.
