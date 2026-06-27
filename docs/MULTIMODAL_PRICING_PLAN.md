# Multimodal pricing plan — recording more than text tokens

Companion to the **Architecture** section of `CLAUDE.md`. This is a work-breakdown
for teaching the catalogue to record models that price more than text input and
output: their input/output modalities, and the extra price dimensions
(image, audio, cache writes, per-request fees) that a multimodal model bills.

Read the **Architecture** and **Copy style** sections of `CLAUDE.md` first. This
file is the *what* and the *order*.

> **Status:** Proposed. Nothing here is built yet.

---

## What "multimodal" means here, and what it doesn't

The site tracks **text-generation** pricing — the cost of running a model that
takes a prompt and returns text. That framing stays. We are not adding
image-generation models, embedding models, or speech-to-text endpoints to the
catalogue; the `text_output?` gate in `OpenRouter::ModelSync` that skips them
(`app/models/open_router/model_sync.rb:249`) is correct and stays.

What's missing is everything a **text-output model that also accepts other inputs**
costs and advertises. A model like GPT-4o or Gemini 2.5 takes images and audio as
input and prices them separately from text tokens, and the catalogue currently
records none of that:

- **Modality metadata.** OpenRouter exposes `architecture.input_modalities` and
  `architecture.output_modalities`. We read `output_modalities` only to filter
  (`model_sync.rb:250`) and store neither. So the catalogue can't say "this model
  reads images" — there's no `multimodal?`, no badge, no filter.
- **Non-text price dimensions.** OpenRouter's `pricing` object carries
  `image`, `audio`, `request`, and `input_cache_write` alongside the
  `prompt` / `completion` / `input_cache_read` we already ingest
  (`model_sync.rb:228`–`234`). We drop all of them.

So "handling multimodal properly" is: **record the modalities a model supports,
and record the prices it charges for non-text inputs** — then show both.

---

## Where the text-tokens-only assumption lives

The assumption is baked into five layers, top to bottom:

| Layer | File | What's hardcoded |
|-------|------|------------------|
| Schema | `db/schema.rb:73`–`85` | `price_points` has exactly three rate columns; `ai_models` has no modality columns |
| Record | `app/models/price_point.rb:7`–`11`, `app/models/ai_model.rb:68`–`70` | validations + accessors for input/output/cached only |
| Read model | `app/models/price_catalog.rb:12`, `:35`–`42` | `Snapshot = Data.define(:date, :input, :output, :cached)` |
| Sync | `app/models/open_router/model_sync.rb:225`–`252`, `:261`–`292` | `parse_pricing` reads three keys; `record_price`/`same_price?` diff three; modalities used only to filter |
| Surface | admin form + params (`admin/price_points`), public API (`api/v1/models_controller.rb:18`), model/provider views, sort sets | three price fields everywhere |

Cost math (`CostEstimate#price_with`, `FeaturePattern::Shape`) is a sixth layer,
but a separable one — see Phase 3.

---

## The phasing

Three phases, each independently shippable and revertible. Phase 1 delivers
visible value (a "reads images/audio" badge) on its own; Phase 2 adds the prices;
Phase 3 is the cost-math redesign and is optional. Ship in order — each later
phase reads the data the earlier one records.

### Phase 1 — Modality metadata · branch `claude/multimodal-modalities`

Record what a model can read and emit, independent of price.

- **Migration.** Add to `ai_models`: `input_modalities` and `output_modalities`
  as `t.json` (SQLite + the Rails 8 JSON type; default `[]`). These hold small
  string arrays like `["text", "image"]`.
- **Sync.** In `enrich` (`model_sync.rb:338`), read
  `row.dig("architecture", "input_modalities")` and `output_modalities`, normalise
  to a sorted, lowercased string array, and assign. Follow the existing
  augment-don't-clobber rule: overwrite for rows we own
  (`source == OPENROUTER_SOURCE`), fill only blanks for curated/linked rows — the
  same shape as the `description`/`context_window` handling right above it.
- **Record.** `AiModel#multimodal?` (`input_modalities` beyond `["text"]`), plus
  readers the views can call. A model with no recorded modalities reads as
  text-only, so existing rows degrade quietly.
- **Surface.**
  - Model page and the models index: a small badge listing non-text input
    modalities. Copy style: state the fact ("Reads images, audio"), not a label
    that performs novelty.
  - Optional `modalities` key on the public model JSON
    (`api/v1/models_controller.rb`) — additive, existing keys unchanged.
  - Optional filter on the models index ("multimodal only"). Defer if it
    crowds the page.
- **Tests / fixtures.** Extend the `or_model` helper
  (`test/models/open_router/model_sync_test.rb`) with `input_modalities:`; add a
  multimodal fixture; assert the badge and the `multimodal?` predicate.

**Acceptance:** a synced GPT-4o-class row reports `input_modalities` including
`image`; the model page badges it; text-only rows look unchanged; suite green.

### Phase 2 — Non-text price dimensions · branch `claude/multimodal-prices`

Record and show the extra rates. **Depends on the schema and read-model seams; do
after Phase 1 lands.**

- **Migration.** Add nullable columns to `price_points`, mirroring the existing
  `cached_input_per_mtok` precedent (nil = "model doesn't charge for this"):
  - `cache_write_per_mtok` — direct analog of cached read; OpenRouter
    `input_cache_write`, per token → our per-MTok convention.
  - `image_input_usd` — OpenRouter `pricing.image`, **per image** (not per token).
  - `request_usd` — OpenRouter `pricing.request`, **per request**.
  - `audio_input_per_mtok` — OpenRouter `pricing.audio`. **Open question:** verify
    the unit against a live response before committing the column name — audio is
    quoted per-token by some providers and per-second by others. Name the column
    for whatever the unit actually is; don't guess it into `per_mtok` if it's
    per-second.

  > **Decision — fixed columns, not JSON.** A JSON `extra_prices` blob would avoid
  > a migration per dimension, but it can't be validated, sorted, or queried, and
  > it cuts against the relational, append-only `PricePoint` the rest of the app
  > reads. OpenRouter's extra dimensions are a small, stable set, so fixed columns
  > (the `cached_input_per_mtok` pattern, extended) stay in-style. Revisit only if
  > a provider appears with a genuinely open-ended pricing shape.

- **Validations** (`price_point.rb`): each new column
  `numericality: { greater_than_or_equal_to: 0 }, allow_nil: true`, matching
  `cached_input_per_mtok`.
- **Sync.** Extend `parse_pricing` (`model_sync.rb:225`) to pull the new keys via
  the existing `to_mtok` (for per-token rates) and a sibling per-unit parser (for
  per-image / per-request, which must **not** be multiplied by `PER_MTOK`).
  Extend `record_price` and `same_price?` (`:261`, `:285`) to write and diff the
  new fields, so a change in image price alone still writes a snapshot. The Slack
  digest's `RepricedRecord` stays keyed on input/output — leave it unless a
  non-text reprice is worth announcing.
- **Read model.** Extend `PriceCatalog::Snapshot` (`price_catalog.rb:12`) and the
  `Entry` price readers (`:51`–`53`) with the new fields. Everything downstream
  reads through here, so this is the single seam.
- **Surface.**
  - Admin price form + `price_point_params` whitelist
    (`admin/price_points_controller.rb`): optional fields, grouped under a
    "Non-text pricing" heading so the common text-only case stays uncluttered.
  - Model page: show non-text rates **only when present** — no empty "Image: —"
    rows on text-only models.
  - Public API price object: additive keys; document them.

**Acceptance:** a multimodal row round-trips image/request/cache-write prices from
sync → catalog → model page and API; a non-text-only reprice writes a new
snapshot; text-only rows render and serialize exactly as before; suite green.

### Phase 3 — Cost math (optional, deferred) · branch `claude/multimodal-cost`

The guide's per-call estimates assume text tokens: `FeaturePattern::Shape =
Data.define(:sys, :in, :out)` (`feature_pattern.rb:25`) and
`CostEstimate#price_with(input:, output:, cached:)` (`cost_estimate.rb:38`). To
price an image-input step, `Shape`/`Profile` need image/audio quantities and
`price_with` needs the matching rates.

All six current launch patterns are text-only, so this delivers nothing until a
multimodal example pattern exists to use it. Keep it behind Phases 1–2:

- Extend `Shape`/`Profile` with optional non-text quantities (default 0, so every
  existing pattern is unchanged).
- Extend `price_with` to add their cost, reading the Phase 2 rates through
  `FeaturePattern::Cost` (`feature_pattern/cost.rb`). Preserve the cache-parity
  invariant noted in that file verbatim.
- Add at least one multimodal pattern (e.g. document/vision Q&A) so the new
  parameters are exercised and the guide shows a non-text cost breakdown.

**Acceptance:** existing patterns produce identical figures; the new pattern
prices image input; cache-parity test still asserts the uncached basis.

---

## Dependency graph & order

```
Phase 1 (modalities)   ── ships alone; badge + API metadata
        │
Phase 2 (prices)       ── after 1; reads no Phase-1 data but shares the surface
        │
Phase 3 (cost math)    ── optional; only worthwhile once a multimodal pattern exists
```

Phases 1 and 2 touch disjoint columns (`ai_models` vs `price_points`) and could in
principle be parallelised, but they overlap on the model-page view and the API
serializer, so sequencing them avoids a merge conflict there. One phase per PR —
small, reviewable, independently revertible.

## Open questions to resolve before Phase 2

1. **Audio unit.** Per-token or per-second? Fetch a live OpenRouter row for an
   audio-input model and read `pricing.audio` against `architecture` before naming
   the column.
2. **Image unit.** Confirm `pricing.image` is per-image across providers (it is
   for the OpenAI/Google rows) and not per-image-token for any we ingest.
3. **API contract.** Whether the public JSON should nest non-text rates under a
   `multimodal:` key or flatten them alongside `input`/`output`. Additive either
   way; pick before publishing.

## Green gate

Every phase ends on the `preflight` skill (RuboCop, Brakeman, bundler-audit,
importmap audit, full test suite, seed replant) before push, per `CLAUDE.md`.
Credential-touching tests stub with `stub_anthropic_key!` / `stub_admin_digest!`.
