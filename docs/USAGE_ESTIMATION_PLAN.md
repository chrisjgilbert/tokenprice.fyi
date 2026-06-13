# Usage Estimation Calculator — Implementation Plan (agent-orchestrated)

*Written June 2026 for an autonomous build. This document is the single source of
truth for a **coordinator agent** that dispatches **specialist sub-agents** to
implement and review the work. It is grounded in the current codebase (Rails 8,
server-rendered ERB, zero-JS house style, SQLite, append-only `PricePoint`
history, pure-Ruby service objects, Minitest).*

The product rationale lives in `docs/PRODUCT_VISION.md` (§4–5 and "Bet 1"). This
plan turns that bet into buildable, parallelizable work packages.

---

## 0. What we are building

A **workload cost calculator** that turns the site from "what does a million
tokens cost?" into "what will *my feature* cost, on which model, and what's the
cheaper alternative?" — plus the smaller insight surfaces that fall out of the
same estimation engine.

Scope is phased. **Phase 1 (MVP) is the deliverable**; Phases 2–3 are follow-on
packages the coordinator may dispatch if Phase 1 lands green and time remains.

**MVP user story:** a developer lands on `/calculator`, picks a task profile (or
types plain-language sizes, or enters raw tokens), sets a monthly volume, and
sees a side-by-side monthly bill across a model shortlist — with the headline
"switching from A to B saves $X/mo (−Y%)" — at a **shareable permalink** whose
numbers recompute at today's prices.

### Non-negotiable design constraints (enforced at review)

1. **Zero-JS-framework, server-rendered.** State lives in **query params** (like
   `ModelsController#index`). Stimulus is allowed only as progressive
   enhancement; the page must fully work with JS disabled.
2. **All money flows through one engine.** No ad-hoc arithmetic in views or
   controllers. The `CostEstimator` service (WP1) is the only thing that
   multiplies tokens by prices. Format only via `PriceFormat` / `usd` helpers.
3. **Estimates derive from `PricePoint`s at render time** — never cached numbers
   — so a shared permalink recomputes at today's prices. This is the moat.
4. **Honest math.** Include cache-read *and* cache-write, batch discounts, and
   thinking-tokens-billed-as-output. State every assumption inline. Frame
   accuracy as ±30%, not false precision. Degrade gracefully when a model lacks
   batch/cache data (hide the toggle, don't fake a ×0.5).
5. **Curation over automation.** Task profiles and cookbook recipes are
   hand-authored editorial content, date-stamped and revisable — same posture as
   the rest of the catalogue.

---

## 1. Agent roles & operating model

### Coordinator agent (the orchestrator)

Owns the branch `claude/usage-estimation-calculator-azcizc`, the work-package
checklist, sequencing, integration, and the final push. **Does not write feature
code itself** — it dispatches specialists, runs the review gate, integrates, and
keeps the suite green.

Operating procedure:

1. **Maintain a live status checklist** of every work package (state: `todo` /
   `in-progress` / `in-review` / `done` / `blocked`). Refresh it each turn.
2. **Dispatch by wave** (see §3 dependency graph). Within a wave, packages that
   touch disjoint files run **in parallel** — launch them in a single message
   with multiple `Agent` calls, using `isolation: "worktree"` so they don't
   collide. Across waves, respect dependencies.
3. **After each implementation package**, dispatch the **reviewer** before
   integrating. Implementers do not review their own work.
4. **Integrate** each accepted package onto the branch, then run the full gate
   (`bin/rails test` + `bin/rubocop`). If integration breaks the suite, the
   coordinator fixes the merge or bounces it back to the implementer — it never
   commits red.
5. **Commit per package** with a clear message; **push once** at the end (or per
   wave) with `git push -u origin claude/usage-estimation-calculator-azcizc`,
   retrying on network error with exponential backoff (2s/4s/8s/16s).
6. **Do not open a PR** unless the user explicitly asks.
7. **Stop and ask** (via `AskUserQuestion`) only on genuine scope changes or
   destructive choices — otherwise proceed.

### Specialist sub-agents

Spawn with the `general-purpose` (or `claude`) agent type and the role prompt
below. Each gets: this document's path, its work-package section, and the
**interface contracts** from §2 so parallel agents build against stable seams.

| Role | Responsibility | Touches |
|---|---|---|
| **domain-engineer** | Service objects, models, migrations, seed data logic | `app/services/`, `app/models/`, `db/migrate/`, `db/seeds.rb` |
| **web-engineer** | Routes, controllers, views, helpers, minimal Stimulus | `config/routes.rb`, `app/controllers/`, `app/views/`, `app/helpers/`, `app/javascript/` |
| **curator** | Editorial content: task-profile params, cookbook recipes, batch/cache price values + sources | `db/seeds.rb`, `lib/data/`, profile/recipe definitions |
| **test-engineer** | Fills coverage gaps; each implementer writes happy-path tests, this role adds edge cases | `test/` |
| **reviewer** | Code review against §4 checklist; runs `/code-review`; verifies house-style + honest-math bar | read-only + review comments |

The **curator** and **test-engineer** roles may be folded into the domain/web
implementers for small packages — the coordinator decides per package. The
**reviewer must always be a separate agent** from the implementer.

---

## 2. Interface contracts (lock these first — everything depends on them)

These are the seams that let agents work in parallel without stepping on each
other. The coordinator must hold these stable; changes to a contract require
re-notifying every dependent package.

### 2.1 `Workload` (value object — WP1)

A description of one workload, independent of any model. Pure data.

```ruby
# app/services/cost_estimator.rb (or its own file)
Workload = Data.define(
  :input_tokens,        # avg input (prompt) tokens per request
  :output_tokens,       # avg output tokens per request (incl. reasoning/thinking)
  :cached_input_tokens, # portion of input served from cache per request (0 if none)
  :requests_per_month,  # volume
  :cache_write_share,   # 0.0–1.0: fraction of cached tokens that incur a write this period
  :batch_share          # 0.0–1.0: fraction of requests eligible for the batch API
)
```

Defaults: `cached_input_tokens: 0`, `cache_write_share: 0`, `batch_share: 0`.
Validation/clamping lives in the engine, not the controller.

### 2.2 `CostEstimator` (service — WP1)

The **only** place tokens are multiplied by prices.

```ruby
estimate = CostEstimator.new(model, workload).call
# => Estimate value object
```

`Estimate` exposes (all monthly unless named otherwise):

- `monthly_cost` — total $/month, the headline number
- `cost_per_request`
- `input_cost`, `output_cost`, `cached_input_cost`, `cache_write_cost` — the breakdown
- `batch_savings`, `cache_savings` — $ saved by each lever vs. the all-fresh baseline
- `assumptions` — array of human-readable strings the view renders inline
- `available_levers` — e.g. `[:cache, :batch]`; omits a lever the model has no price for

Rules the engine enforces:

- Reads prices from `model.current_price` (a `PricePoint`). Returns a clearly
  "unpriced" estimate (nil `monthly_cost`) if the model has no price — callers
  skip it rather than render `$0`.
- `output_tokens` already includes thinking/reasoning tokens (billed at the
  output rate); the engine does **not** add a separate reasoning line, but its
  `assumptions` note that thinking tokens count as output.
- Batch and cache-write use the new `PricePoint` columns (WP2). When a column is
  nil, that lever is dropped from `available_levers` and contributes $0 savings —
  never a hand-waved multiplier.
- Money math uses `BigDecimal`/`Rational` internally (prices are `decimal`),
  rounding only at the formatting boundary.

### 2.3 `PricePoint` new columns (migration — WP2)

Nullable decimals, same precision as existing price columns
(`precision: 12, scale: 6`), curated like everything else:

- `batch_input_per_mtok`
- `batch_output_per_mtok`
- `cache_write_per_mtok`

`cached_input_per_mtok` already exists (cache *read*). Migration must not alter
existing rows; columns default nil and are populated by the curator (WP3b) only
where a provider publishes the figure.

### 2.4 `TaskProfile` (registry — WP3)

**MVP decision: a static, code-defined registry — not a DB model yet.** Mirrors
the catalogue's "curated constant" instinct, needs no admin UI, and is trivial
to permalink. (The vision doc's `TaskProfile` *model* is a deliberate Phase-3
graduation, recorded in §6.)

```ruby
# app/services/task_profile.rb  (PORO registry, frozen)
TaskProfile = Data.define(:slug, :name, :blurb, :token_shape, :min_tier, :as_of)
# token_shape => { input:, output:, cached_input: }  (per-request averages)
TaskProfile::ALL  # ordered Array; TaskProfile.find(slug)
```

Seed with the 8 archetypes from `PRODUCT_VISION.md` §4 (classification, JSON
extraction, RAG answering, long-doc summarisation, customer chat, code gen,
multi-step agents, deep reasoning). Each carries an `as_of:` date stamp.

A profile + a volume + a chosen `cache_write_share`/`batch_share` is enough to
build a `Workload`. The calculator's three input modes (§ WP4) all ultimately
produce a `Workload`.

### 2.5 Permalink param schema (WP4) — stable & documented

`/calculator?profile=rag&volume=300000&out=900&cache_hit=0.8&batch=0&models=claude-opus-4-8,gpt-5-5`

| Param | Meaning | Default |
|---|---|---|
| `mode` | `profile` \| `plain` \| `power` | `profile` |
| `profile` | TaskProfile slug (profile mode) | `rag` |
| `in`,`out`,`cached` | per-request tokens (power mode) | from profile |
| `pages_in`,`para_out`,`sys_words` | plain-language sizes (plain mode) | — |
| `volume` | requests per month | profile-appropriate |
| `cache_hit` | 0–1 | profile default |
| `batch` | 0–1 | 0 |
| `models` | comma-separated slugs (shortlist; empty = frontier headline set, see WP4) | — |

The web-engineer owns parsing/clamping (cap volume, whitelist slugs against
`AiModel.listed`, exactly like `ModelsController` does for `providers`/`sort`).

---

## 3. Work packages & dependency graph

```
WAVE 0 (foundation — must finish & pass review before Wave 1)
  WP1  Estimation engine (Workload, CostEstimator, Estimate)   [domain]   ── blocks everything
  WP2  PricePoint batch/cache-write migration                   [domain]   ── parallel to WP1
  WP3a TaskProfile registry + 8 profiles                        [domain]   ── parallel
  WP3b Batch/cache-write + profile data values (curated)        [curator]  ── needs WP2 schema

WAVE 1 (UI core — parallel, both depend on WAVE 0)
  WP4  Calculator: routes, controller, 3 input modes, results   [web]      ── needs WP1, WP3
  WP5  Per-task price surface on model pages                     [web]      ── needs WP1

WAVE 2 (insight surfaces — optional, depend on WAVE 1)
  WP6  Cost cookbook (curated recipes → link into calculator)   [web+cur]  ── needs WP1, WP4
  WP7  Blended-ratio preset re-rank on homepage (stretch)       [web]      ── needs nothing but WP-conventions

CROSS-CUTTING (every wave)
  WP-T Test hardening pass per package                          [test]
  WP-R Review gate per package                                  [reviewer]
  WP-D Docs: README + this plan's status + JSON-LD/SEO          [web]
```

Parallelism the coordinator should exploit: **WP1 ‖ WP2 ‖ WP3a** in Wave 0
(disjoint files, use worktrees); **WP4 ‖ WP5** in Wave 1. WP3b waits on WP2's
migration landing.

---

## 4. Per-package specs

Each package below is a ready-to-paste brief for a specialist agent. Every
package's **Definition of Done**: code + happy-path tests written, `bin/rails
test` green, `bin/rubocop` clean, reviewer sign-off, coordinator integrated.

### WP1 — Estimation engine  *(domain-engineer)*

- **Goal:** the `Workload` / `CostEstimator` / `Estimate` contract in §2.1–2.2.
- **Files:** `app/services/cost_estimator.rb` (+ `task_profile.rb` if co-located).
- **Build against §2.2 exactly.** Pure Ruby, no Rails-request coupling — same
  shape as `ModelInsights`/`PriceFormat` so it's unit-testable in isolation.
- **Tests** (`test/services/cost_estimator_test.rb`): a fixture model with known
  prices → assert breakdown, per-request, monthly; cache-read reduces input
  cost; `batch_share`/`cache_write_share` move the levers; nil batch/cache
  columns drop the lever (no fake discount); unpriced model → nil `monthly_cost`;
  thinking-as-output noted in `assumptions`.
- **Acceptance:** given a 1000-in/500-out/0-cached workload at 100k req/mo on a
  $3/$15 model, `monthly_cost` equals the hand-computed figure; toggling batch to
  1.0 with batch prices set reduces it by exactly the published batch delta.

### WP2 — PricePoint batch/cache-write columns  *(domain-engineer)*

- **Goal:** the three nullable decimal columns in §2.3.
- **Files:** `db/migrate/<ts>_add_batch_and_cache_write_to_price_points.rb`,
  regenerated `db/schema.rb`.
- **Constraints:** nullable, no backfill, no change to existing rows; keep the
  unique index on `[ai_model_id, effective_on]` intact.
- **Tests:** model test asserting the columns exist and accept nil; existing
  `price_point_test.rb` stays green.
- **Acceptance:** `bin/rails db:migrate` then `db:rollback` both clean.

### WP3a — TaskProfile registry  *(domain-engineer)*

- **Goal:** §2.4 registry + the 8 archetypes from `PRODUCT_VISION.md` §4.
- **Files:** `app/services/task_profile.rb`.
- **Tests:** `test/services/task_profile_test.rb` — `ALL` is frozen & ordered,
  `find` works and is nil-safe, every profile has a positive token shape and an
  `as_of` date.

### WP3b — Curated price & profile values  *(curator)*  *(needs WP2)*

- **Goal:** populate batch/cache-write prices in `db/seeds.rb` **only where a
  provider publishes them**, each with a `src:`/`note:` (matches existing seed
  discipline); tune the WP3a token shapes to realistic averages with `as_of`
  stamps.
- **Files:** `db/seeds.rb`, `app/services/task_profile.rb` (values only).
- **Constraints:** idempotent seed; never invent figures — leave nil if
  unpublished. Anthropic authoritative; others best-effort with source.
- **Acceptance:** `bin/rails db:seed` idempotent; spot-check 3 models' batch
  prices against cited sources in the note.

### WP4 — Calculator (routes, controller, views)  *(web-engineer)*  *(needs WP1, WP3)*

- **Goal:** the MVP user story. `GET /calculator` (add to `routes.rb` as
  `calculator`).
- **Files:** `config/routes.rb`, `app/controllers/calculators_controller.rb`,
  `app/views/calculators/show.html.erb` (+ partials), maybe
  `app/javascript/controllers/calculator_controller.js` (progressive enh. only),
  helper additions in `app/helpers/`.
- **Behaviour:**
  - Parse the §2.5 param schema; clamp/whitelist like `ModelsController#index`.
  - Three input modes (`profile` default, `plain`, `power`) → all build a
    `Workload`; plain mode converts via ~4 chars/token with the assumption shown.
  - **Default the model shortlist to the frontier headline set when `models` is
    empty** — i.e. the listed frontier-tier models (`AiModel.listed.frontier`),
    the same set the homepage's cheapest-frontier headline ranks — ordered by
    `CostEstimator#monthly_cost` cheapest-first for the chosen workload. Cap at a
    readable N (e.g. 6) so a bulk import can't bloat the table; the user can
    always widen via the `models` param. (This default is deliberate, not
    "sensible-ish": it anchors the calculator on the comparison users arrive for.)
  - Render a side-by-side monthly-bill table: per model `monthly_cost`,
    `cost_per_request`, the breakdown, and per-lever "with caching / with batch"
    figures (only for models exposing that lever).
  - **Headline delta row:** cheapest vs. a chosen/most-expensive baseline —
    "Switching from A to B saves $X/mo (−Y%)". This is the screenshot artifact.
  - **Sensitivity line:** "at 2× volume: $Z".
  - **Permalink:** current state is fully reconstructable from the URL; include a
    copy-link affordance. Works with JS off (it's just the address bar).
  - Inline **assumptions** block from `Estimate#assumptions` + a ±30% caveat.
  - Reuse `PriceFormat`/`usd` for all money. Match the existing visual system
    (Tailwind classes, `tp-*` conventions seen in `application_helper.rb`).
- **Tests** (`test/controllers/calculators_controller_test.rb`, mirror
  `comparisons_controller_test.rb`): renders with no params (defaults); with no
  `models` param the shortlist is the frontier headline set, cheapest-first; a
  full permalink reproduces a known bill; bad/oversized params are clamped not
  500; an unpriced model is skipped; the savings delta renders.
- **Acceptance:** a permalink pasted fresh renders the same shortlist & numbers;
  page passes with JS disabled.

### WP5 — Per-task price on model pages  *(web-engineer)*  *(needs WP1)*

- **Goal:** reframe model pages from token prices to task prices. Add a small
  section to `app/views/models/show.html.erb`: "A RAG answer on this model ≈
  $0.0009 · a 50-page summary ≈ $0.11", plus a **downgrade ladder** line ("same
  workload one tier down: −83%") and a deep link into `/calculator` pre-filled
  for that model.
- **Files:** `app/views/models/show.html.erb`, likely a new
  `app/services/model_task_prices.rb` (wraps `CostEstimator` over a couple of
  reference profiles), or extend `ModelInsights`.
- **Tests:** service test for the per-task figures; `models_controller_test.rb`
  asserts the section renders for a priced model and is absent/safe for unpriced.
- **Acceptance:** figures equal `CostEstimator` output for the reference
  profiles; downgrade ladder picks a real cheaper same-workload model or hides.

### WP6 — Cost cookbook  *(web-engineer + curator)*  *(needs WP1, WP4)*

- **Goal:** `/cookbook` (and `/cookbook/:slug`) — ~5 curated, annotated real
  examples (a support-ticket classification, a RAG answer over a 30-page PDF, a
  40-turn agent session, a long-doc summary, a JSON extraction). Each shows the
  token breakdown and cost across a 5–6 model shortlist, and a **one-click "open
  in calculator"** preset link.
- **Files:** `config/routes.rb`, `app/controllers/cookbook_controller.rb`,
  `app/views/cookbook/`, a curated recipe registry (PORO/YAML in `lib/data/` or
  `app/services/`), sitemap + JSON-LD additions.
- **Tests:** index + each recipe renders; costs come from `CostEstimator`; the
  calculator preset link round-trips.
- **Acceptance:** every recipe is date-stamped, sourced where it cites real
  prompts, and its costs match the calculator for the same inputs.

### WP7 — Blended-ratio presets (stretch)  *(web-engineer)*

- **Goal:** make the homepage's hidden 3:1 blend a feature: preset links
  (1:1 / 3:1 / 10:1 / 20:1) that re-rank the table via a query param, with a
  callout that ranking shifts for input-heavy workloads.
- **Files:** `app/models/ai_model.rb` (parametrize `blended_per_mtok` weights —
  it already takes a price arg; add an optional ratio), `models_controller.rb`
  (accept `ratio` param, whitelist), `app/views/models/index.html.erb`.
- **Tests:** ranking changes with ratio; default unchanged; bad ratio ignored.
- **Note:** only start if Wave 1 is green and time remains; it touches the
  hot-path homepage controller, so review scrutiny is higher.

### WP-R — Review gate  *(reviewer, after every implementation package)*

Run `/code-review` on the package diff, then verify the §1 constraints and the
checklist in §5. Block on any constraint violation. Return findings to the
coordinator with severity; the coordinator routes fixes back to the implementer.

### WP-D — Docs & SEO  *(web-engineer, final)*

- Update `README.md` (new routes, the estimation engine, the new columns).
- Add `/calculator` and `/cookbook` to `app/controllers/sitemaps_controller.rb`.
- JSON-LD / canonical / meta for the new pages (match existing SEO posture).
- Update this file's §7 status table to `done`.

---

## 5. Review checklist (the reviewer enforces; the coordinator won't integrate without it)

**Correctness & honesty**
- [ ] All money goes through `CostEstimator`; no arithmetic in views/controllers.
- [ ] Numbers derive from `PricePoint`s at render time (a permalink recomputes).
- [ ] Batch/cache-write use real columns; a missing column drops the lever, never fakes a discount.
- [ ] Thinking/reasoning tokens treated as output and disclosed in assumptions.
- [ ] Unpriced models are skipped, not shown as `$0`.
- [ ] Assumptions + ±30% framing visible to the user.

**House style**
- [ ] Zero-JS-framework; page works with JS disabled; Stimulus is enhancement only.
- [ ] State in query params; params clamped & whitelisted (no 500s on junk input).
- [ ] Money formatted via `PriceFormat`/`usd`; Tailwind/`tp-*` conventions reused.
- [ ] Service objects mirror `ModelInsights`/`PriceFormat` shape; nil-safe.

**Quality gates**
- [ ] `bin/rails test` green; new code has happy-path **and** edge-case tests.
- [ ] `bin/rubocop` clean.
- [ ] Curated data carries `source`/`note`; seed stays idempotent.
- [ ] No N+1 in the calculator (eager-load `:provider, :price_points` like the existing controllers).

---

## 6. Decisions locked vs. deferred

**Locked for MVP**
- TaskProfile is a **static code registry**, not a DB model (no admin UI yet).
- Calculator state is **URL-only** (no accounts, no saved estimates).
- Plain-language mode uses a **flat ~4 chars/token** heuristic, disclosed — no
  per-family tokenizer in MVP.

**Deferred (Phase 3 / later bets — do not build now without the user asking)**
- Paste-a-prompt mode with a real tokenizer (`tiktoken_ruby`): fold in as a 4th
  calculator input mode once the core ships. Listed in the user's brainstorm;
  intentionally not MVP because a single prompt's cost ≠ the monthly-bill question.
- Graduating TaskProfile/recipes to **admin-curated DB models**.
- Price-change **alerts / RSS / changelog** (Vision "Bet 2") — separate effort.
- Public **JSON API** for estimates.
- Budget-first inversion ("what does $100/mo buy?"), system-prompt-tax ROI line.

These are recorded so the coordinator can scope a follow-up without re-deriving
the brainstorm — but they are **out of scope for this build** unless the user
asks.

---

## 7. Status (coordinator keeps this current)

| WP | Title | Wave | State | Reviewer |
|---|---|---|---|---|
| WP1 | Estimation engine | 0 | todo | — |
| WP2 | PricePoint batch/cache-write columns | 0 | todo | — |
| WP3a | TaskProfile registry | 0 | todo | — |
| WP3b | Curated price/profile values | 0 | todo | — |
| WP4 | Calculator UI | 1 | todo | — |
| WP5 | Per-task price on model pages | 1 | todo | — |
| WP6 | Cost cookbook | 2 | todo | — |
| WP7 | Blended-ratio presets (stretch) | 2 | todo | — |
| WP-D | Docs & SEO | 3 | todo | — |

**Definition of done (whole build):** Phase 1 (WP1–WP5) integrated on
`claude/usage-estimation-calculator-azcizc`, full suite + rubocop green,
reviewer signed off each package, README updated, branch pushed. No PR unless
the user asks.
```
