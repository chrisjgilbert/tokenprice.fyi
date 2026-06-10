# PRD: tokenprice.fyi — From Pricing Table to Decision Layer

| | |
|---|---|
| **Status** | Draft for review |
| **Author** | Product (review of June 2026) |
| **Companion doc** | [`docs/PRODUCT_VISION.md`](./PRODUCT_VISION.md) — strategy, rationale, competitive context |
| **Scope** | Four workstreams: cost calculator, price alerts + changelog, task-profile picker, public JSON API |

---

## 1. Overview

tokenprice.fyi today is a normalized, history-backed LLM API pricing table. It answers *"what does a million tokens cost?"* — a question users can answer in many places. This PRD covers the work to make it answer three questions users can't answer anywhere else:

1. **"What will my workload cost, on which model?"** → Workload cost calculator
2. **"Tell me when the answer changes."** → Price alerts + public changelog
3. **"What's the cheapest model that's good enough for this task?"** → Task-profile picker

Plus one distribution play: a **free JSON API** that makes tokenprice.fyi the canonical normalized source others build on.

### Positioning (north star for all copy and scope decisions)

> tokenprice.fyi is the live price index for LLM APIs — every model, every provider, normalized, sourced, and tracked over time. Estimate what your workload will actually cost, find the cheapest model that's good enough, and get told the moment the market moves.

### Guiding principles

- **Task prices, not token prices.** Every new surface expresses cost in $/task and $/month wherever possible; $/Mtok is the raw material, not the answer.
- **Honest arithmetic.** Assumptions stated inline; include caching, batch, and thinking-token effects or say explicitly that we don't.
- **Curation over automation.** Editorial judgments (tier fit, task profiles) are dated, sourced, and revisable — same posture as the existing price data.
- **Server-rendered, shareable, indexable.** State lives in URLs. No JS framework. Every output is a permalink that SEO can find and users can paste into a planning doc.

### Non-goals (explicitly out of scope)

- Quality **benchmarks** or eval scores (arms race; off-brand; link out instead).
- An inference **gateway/proxy** or key management (that's OpenRouter).
- **Spend tracking** via customers' provider API keys (different product; revisit post-audience).
- User accounts beyond what alerts minimally require (email-token auth, not a full identity system).
- Non-USD currencies, fine-tuning/embedding/image-generation pricing (v2 candidates).

---

## 2. Users & Jobs

| Persona | Context | Job to be done |
|---|---|---|
| **Builder** (indie dev / founder) | Pre-build or prototyping; no production token data | "Given my use case, what would this cost per month on each candidate model — and which cheap model is good enough?" |
| **Team lead** (eng/platform lead at a shipping team) | Has rough production numbers; reviews model choice quarterly at best | "Quantify the delta between our current model and alternatives; justify a switch (or staying) in a doc." |
| **Watcher** (anyone who has shipped) | Post-launch; not actively shopping | "Ping me when a price drops or a cheaper-equivalent model ships. Don't make me check." |
| **Integrator** (tool/dashboard/content builder) | Building something that needs pricing data | "Give me clean, normalized, fresh pricing JSON I can rely on and cite." |

Moments served: **before building** (calculator, picker), **while building** (picker, compare), **after launch** (alerts, changelog, API).

---

## 3. Success Metrics

**North star: weekly returning users** (the table today has effectively none — SEO arrivals bounce in <1 min).

| Workstream | Primary metric | 90-day target post-launch |
|---|---|---|
| Calculator | Estimates created; % with shared/revisited permalink | 25% of sessions touching calculator create an estimate; 10% of estimates re-opened from a shared URL |
| Alerts + changelog | Alert subscribers; email open rate | 500 subscribers; >45% open on price-change sends |
| Task picker | Organic entrances to profile pages; profile → calculator click-through | Profile pages = 20% of organic entrances; >30% CTR to calculator |
| JSON API | Distinct consuming origins/tokens per week | 50 weekly active consumers |

**Guardrails:** data accuracy incidents (wrong price reported) = 0 tolerated without a same-day correction note; p75 page load < 1s (server-rendered budget); email complaint rate < 0.1%.

---

## 4. Workstream A — Workload Cost Calculator

*Priority: P0 — ship first. Everything else links into it.*

### A.1 User stories

- As a **Builder**, I pick a task type and a volume and see a ranked monthly bill across all models, without knowing what a token is.
- As a **Team lead**, I enter my measured per-request tokens, cache hit rate, and batch share, and get a defensible side-by-side I can paste into a planning doc.
- As any user, I share a URL and my teammate sees the same estimate — recomputed at **today's** prices, with a note when prices have moved since the link was made.

### A.2 Functional requirements

**Inputs — three modes, one form (progressive disclosure):**

| Mode | User provides | We derive |
|---|---|---|
| **Profile** (default) | Task profile (from Workstream C) + volume (requests/day or /month) | Token shape from the profile's parameters |
| **Plain language** | Prompt size & response size in pages/paragraphs/words; optional system-prompt size | Tokens at ~4 chars/token (≈0.75 words/token), assumption shown inline |
| **Power** | Input/output/cached-read/cached-write tokens per request; cache hit rate %; batch share %; thinking-token allowance | Used as-is |

- Defaults pre-filled everywhere; a user who only picks a profile and a volume gets a complete answer.
- Model scope: default = all `listed` models; user can narrow to a shortlist (multi-select, reusing existing provider/tier filter patterns).

**Computation (server-side, from current `PricePoint`s):**

- Per model: **$/task**, **$/month**, with explicit line items: input, output, cached input (read), cache write where priced, batch-discounted share.
- Thinking/reasoning tokens billed as output where applicable (flag on model; see A.4).
- **Sensitivity band:** cost at 0.5× and 2× the stated volume.
- **Delta row:** "vs. [reference model]: −$1,840/mo (−62%)" — reference model selectable, defaults to the most expensive shortlisted model (or the user's declared current model).
- Models missing a needed price dimension show "—" with a tooltip, never a silently wrong number.

**Outputs:**

- Ranked table (cheapest first), provider squares and tier badges reusing existing helpers.
- **Permalink:** all state in query params (`/calculator?profile=rag&volume=300000&period=month&models=claude-haiku-4-5,gpt-5-mini&cache=70`). No persistence required for v1.
- **Live recompute notice:** when any shortlisted model's `current_price.effective_on` is later than a `priced_at` param embedded at share time, show "Prices have changed since this estimate was shared — recalculated at today's rates" with a link to the relevant model changelog.
- Per-task price surfaced on **model show pages** too: "A typical RAG request on this model ≈ $0.0042" (computed from 2–3 marquee profiles).

### A.3 UX requirements

- Single page, `/calculator`. Form on top, results below; Turbo-frame the results so mode/filter changes don't repaint the form (same pattern as the homepage table).
- Works without JS (noscript submit button, as on the homepage filters).
- Assumptions footer on every result: token-conversion ratio, blend of price dimensions used, what's excluded (rate limits, fine-tuning, image tokens).
- Copy-link button; OG meta tags so shared links unfurl with the headline number.

### A.4 Data/engineering notes

- No new tables required for v1. Two new columns on `ai_models`: `cache_write_per_mtok_multiplier` is **not** needed — instead add `cached_write_per_mtok` (decimal, nullable) and `batch_discount_pct` (integer, nullable) to `price_points`, since both are price facts that change over time and belong in the append-only history. Add `bills_thinking_as_output` (boolean, default true) to `ai_models`.
- OpenRouter sync: extend `OpenRouter::ModelSync` to populate the new price fields where the API exposes them; manual curation fills the rest (existing manual-wins rules apply).
- Calculation lives in a PORO (`app/services/cost_estimate.rb`) with unit tests covering every line item and the missing-dimension cases.

### A.5 Acceptance criteria

- A user selecting only "RAG answering" + "10,000 requests/day" sees a complete ranked monthly-cost table in one submit.
- A shared permalink opened by another browser reproduces the estimate exactly at current prices; if prices moved since `priced_at`, the recompute notice appears.
- Batch and cache toggles visibly change the ranking when they should (test fixture asserts a known rank flip).
- Page renders fully without JavaScript.

---

## 5. Workstream B — Price Alerts + Public Changelog

*Priority: P0/P1 — start immediately after A ships; the trigger detection already exists.*

### B.1 User stories

- As a **Watcher**, I enter my email on a model page and get an email when that model's price changes.
- As a **Watcher**, I subscribe to "the market" and get a digest when any tracked model's price moves or a notable model launches.
- As anyone, I browse `/changelog` — every price change ever, dated, sourced, filterable — and subscribe via RSS without giving an email.

### B.2 Functional requirements

**Changelog page (`/changelog`):**

- Reverse-chronological feed of: price changes (from `PricePoint` deltas: model, old → new per dimension, % change, source, note), model launches (`released_on`), and curated `MarketEvent`s.
- Filter by provider and kind; permalink per entry (anchor); full-history CSV download link.
- RSS/Atom feed at `/changelog.xml`.
- This page supersedes nothing — the trends chart stays; changelog is the textual, citable record.

**Subscriptions:**

- Subscribe points: model show page ("Watch this model"), changelog page ("Watch the market"), post-calculator ("Watch these 4 models").
- **No accounts.** Email + signed unsubscribe/manage token (Rails `generates_token_for`). Double opt-in confirmation email. Unsubscribe is one click, per-watch and global.
- New table `watches`: `email`, `watchable` (polymorphic: `AiModel`, `Provider`, or null = market), `confirmed_at`, timestamps. Index on email + watchable.

**Sends:**

- **Trigger:** `OpenRouter::ModelSync` already appends a `PricePoint` only when price actually moved — emit an event/callback there; manual admin price-point creation triggers the same path.
- Model-watch email: sent within the hour of detection. Subject: "▼ Claude Haiku 4.5 input price −20%". Body: old/new table, % change, source link, link to model page and to re-run any calculator estimate.
- Market digest: batched **daily**; sent only on days with activity. Never more than one market email per day.
- Mailer via existing Solid Queue; throttle/dedupe job so a multi-model repricing event produces one digest, not N emails.

### B.3 Acceptance criteria

- Seeding a new `PricePoint` for a watched model in staging produces exactly one email to each confirmed watcher, within the job-queue interval.
- A day with five price changes produces one market digest, not five.
- Unconfirmed emails never receive alerts; unsubscribe link works without login.
- `/changelog` lists the DeepSeek V4 75% cut (existing seed) with old → new prices and its source.

---

## 6. Workstream C — Task-Profile Picker

*Priority: P1 — start with 5 profiles; expand based on organic search data.*

### C.1 User stories

- As a **Builder**, I open "Cheapest model for classification" and get a ranked, live-priced answer with a dated editorial judgment about which tier is good enough — and one click pre-fills the calculator.
- As a **Team lead**, I read *why* a profile's cost is dominated by cached-input price (not headline input price) and adjust my caching strategy accordingly.

### C.2 Functional requirements

**`TaskProfile` model (admin-curated, like everything else):**

| Field | Notes |
|---|---|
| `name`, `slug`, `description` | e.g. "RAG answering over documents" |
| `input_tokens`, `output_tokens`, `cached_share_pct` | the canonical token shape per task |
| `min_tier` | editorial floor: `small` / `mid` / `frontier` |
| `dominant_dimension` | enum: which price lever dominates (input / output / cached input) — drives the explainer |
| `rationale` (text), `judged_on` (date) | the dated, revisable editorial judgment |

**Launch set (5 profiles):** classification/routing · data extraction to JSON · RAG answering · long-document summarisation · agentic coding. (Expansion candidates in vision doc §4.)

**Profile pages (`/tasks/:slug`):**

- Hero: the task, its token shape, and the one-line cost insight ("for agents, cached-input price matters more than headline input price").
- Ranked table: cost **per 1,000 tasks** for every model at or above `min_tier`, computed live from current prices via the same `CostEstimate` service as the calculator. Models below the tier floor shown collapsed under "probably not good enough for this — here's why" with the rationale.
- "Estimate my volume" CTA → calculator pre-filled with this profile.
- Dated judgment box: "Tier guidance last reviewed 10 Jun 2026" — staleness > 90 days flags in admin.
- Index page `/tasks` listing all profiles; both indexed, JSON-LD, in sitemap (these pages are the SEO spearhead).

### C.3 Editorial requirements

- Every `min_tier` judgment ships with a written rationale; no bare verdicts.
- Quarterly review cadence owned by the curator (same person/process as Anthropic price curation); admin dashboard lists profiles by `judged_on` age.
- Tone: opinionated, hedged honestly, never benchmark-cosplay. We say "good enough for typical schemas," not "scores 87.2."

### C.4 Acceptance criteria

- All five profile pages render ranked live-priced tables with zero per-request N+1 (eager-load as homepage does).
- Editing a profile's token shape in admin immediately changes its ranking and the calculator preset.
- A price change reorders profile rankings with no further action (verified in test by appending a `PricePoint`).

---

## 7. Workstream D — Public JSON API + Embeds

*Priority: P1 (API) / P2 (embeds) — near-zero effort, pure distribution. Can ship any time.*

### D.1 Requirements

- `GET /api/v1/models.json` — all listed models: slug, name, provider, tier, status, context window, current prices (all dimensions incl. new batch/cache-write fields), `price_effective_on`, `last_verified`.
- `GET /api/v1/models/:slug.json` — model + full price history with sources.
- `GET /api/v1/changelog.json` — the changelog feed, paginated.
- Read-only, no auth, generous cache headers (`Cache-Control`, ETag) via Solid Cache; CORS open. Rate limit by IP (Rack::Attack) to protect SQLite.
- Versioned path; documented on a `/api` page with curl examples and an attribution request ("data by tokenprice.fyi").
- **Embed (P2):** an SVG badge endpoint per model (`/badge/:slug.svg`, input/output price, auto-fresh) for READMEs — server-rendered SVG is already a house specialty.

### D.2 Acceptance criteria

- Full catalogue endpoint responds < 100ms warm-cache; data matches the homepage table exactly (single source of truth — same scopes).
- A price change appears in the API within the same sync cycle as the site.

---

## 8. Cross-cutting Requirements

- **Trust surfacing (do alongside A):** show `last verified` date and per-price-point source links on model pages and in the homepage table tooltip. Add a `/about-the-data` page describing methodology (sync + curation + corrections policy). This is cheap and compounds every other workstream.
- **Blend transparency:** wherever the 3:1 blended figure appears, link it to the calculator ("rank by *your* mix instead").
- **Performance budget:** all new pages server-rendered, p75 < 1s, no client-side data fetching.
- **SEO:** calculator permalinks `noindex` (infinite param space); profile pages, changelog, and `/api` docs indexed with JSON-LD.
- **Privacy:** emails used only for the watches they confirm; no tracking pixels beyond open-rate measurement; deletion on unsubscribe-all.

---

## 9. Phasing & Sequencing

| Phase | Ships | Rationale |
|---|---|---|
| **1** | Calculator (A) + trust surfacing (§8) + new price fields | Highest impact : effort; everything links into it |
| **2** | Changelog page + RSS, then email watches (B) | Retention engine; trigger detection already exists |
| **3** | JSON API (D) | Trivial after A's data work; start the canonical-source flywheel |
| **4** | 5 task profiles (C), wired into calculator presets | Needs A live to be more than content; SEO results guide expansion |
| **5** | Badges/embeds; profile expansion; calculator "current model savings" follow-ups | Compounding loops |

Dependencies: C depends on A's `CostEstimate` service and profile presets. B's "watch these models" post-calculator CTA depends on A. D depends only on the Phase-1 schema additions.

---

## 10. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| **Wrong numbers destroy trust** (the only real asset) | Source links + last-verified everywhere; corrections policy with dated notes; calculator states assumptions inline; "—" over guesses |
| **Tier-fit judgments go stale or get publicly contradicted** | Date-stamp every judgment; quarterly review SLA with admin staleness flags; write hedged rationales, not verdicts |
| **Email infra burden** (deliverability, spam complaints) | Double opt-in; daily digest cap; transactional ESP; complaint-rate guardrail with auto-pause |
| **OpenRouter dependency** (source changes/blocks) | Already mitigated by design: curated data is authoritative and append-only; add a second provider-page scraper source per the existing roadmap |
| **API abuse on SQLite** | Aggressive HTTP caching + rate limiting; the dataset is small and cacheable in full |
| **Scope creep toward benchmarks/dashboards** | Non-goals section above; revisit only with evidence of demand post-Phase 4 |

---

## 11. Open Questions

1. Reference-model default in the calculator delta row: most expensive shortlisted, or ask "what do you use today?" (better story, one more required input).
2. Should calculator estimates be persistable (short-slug saved estimates) in v1, or are query-param permalinks enough until sharing data says otherwise? *(Recommendation: params only; revisit at >10% share-reopen rate.)*
3. Market-digest scope: all ~50+ models incl. OpenRouter imports, or curated models only? *(Recommendation: curated + any model with ≥1 watcher.)*
4. Token-estimation honesty: is ~4 chars/token adequate across languages for plain-language mode, or do we need a per-family heuristic? Validate against real tokenizer counts before launch copy promises anything.
5. API attribution: request-only, or license the dataset (e.g. CC BY) to formalize the citation flywheel?
