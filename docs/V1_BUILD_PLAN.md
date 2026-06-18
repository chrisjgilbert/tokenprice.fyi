# V1 Build Plan — price index + education + a lightweight estimator

*Companion to `PRODUCT_VISION.md` (17 June, revised). Scope = the **tight V1**: nail the price
index, add an education layer, and a lightweight single-workload estimator with two demand
probes. The trace-ingesting measure-&-optimize tool is the **proper product, later** (§11) —
do not build it until the gate is met. Goal: ship the smallest thing that makes the index a
destination and tests demand for the product, with almost no new infrastructure.*

---

## 1. What V1 is (and isn't)

**In:**
- (a) the existing **reference pages**, polished — the hero;
- (b) an **education** layer — evergreen explainers + live-data widgets;
- (c) a **single-workload estimator** (`/cost`) — describe/sliders → cost across every model →
  cheapest-equivalent savings → shareable permalink, embedded on model pages;
- (d) two **demand probes** — "measure my real usage (notify me)" and "alert me when this price
  changes" — capture only.

**Out → the proper product (§11):** measuring real calls (paste-a-trace, CSV import),
multi-step / agent-loop modelling, tools/reasoning inputs, save/watch alert *sending*, any
SDK/CLI/telemetry. The estimator takes *typed* inputs only — so V1 never touches prompt text,
and the privacy story is trivial.

## 2. Principle — reuse the house patterns

- **Server-rendered ERB + a Turbo Frame** for the live estimator result (the homepage already
  swaps the `#models` frame via `filters_controller`).
- **Inline SVG charts via a helper** (`ChartsHelper`).
- **Tailwind + the existing CSS tokens**; port the Claude Design output into this.
- **Tested Ruby (`bin/rails test`)** for the money math; thin vanilla Stimulus only for the
  debounced form + permalink.
- No Node build, no accounts, no email sending, no SDK, no model/price schema changes beyond
  the tiny signups table.

## 3. The data seam (`PriceCatalog`) — the one architectural must

Introduce a single read interface that the estimator (and, later, the product and the public
API) use for prices — never ad hoc model queries:

- `PriceCatalog` service: `models` (listed, with current input/output/cached + context +
  tier), `model(slug)`, `history(slug)`, `as_of(slug, date)`. Backed by `AiModel` today.
- Everything cost-related reads through it. This (a) keeps the future product cleanly
  separable, (b) is the basis of the public **JSON API** (`/api/v1/models.json`) — the
  backlink/citation flywheel and licensed-dataset seed — and (c) lets the product later
  swap/extend data sources ("or other").

## 4. The lightweight estimator (`/cost`)

- **Route:** `get "cost", to: "costs#show"`. State in query params (shareable, indexable).
- **`CostsController#show`** — decode the workload profile from params → `CostEstimate` (via
  `PriceCatalog`) → render; result in `turbo_frame_tag "cost_result"` (frame-only on a frame
  request, like `models#index`).
- **`CostEstimate` PORO** (`app/services/cost_estimate.rb`) — *single workload*:
  `{ sys, fresh, out, req, cache, min_tier, baseline_slug }` → for each catalog model:
  `$/request`, `$/month` (cache blending), context-fit, tier-eligibility; `recommendation` =
  cheapest that fits + meets tier; `savings` vs baseline (`$/mo`, `%`, `$/yr`); `breakdown`
  (input/output/cache); `retrospective` (cheapest fitting model `$/mo` on each price-change
  date, via `PriceCatalog.as_of`). *Structured so a list of steps can slot in later (the
  product) — V1 calls it with one step.*
- **`cost_form` Stimulus controller** — debounced `requestSubmit` + URL sync (a near-clone of
  `filters_controller`); drives the `cost_result` frame and the permalink; copy-link button.
- **Embed:** a compact "estimate your monthly cost" widget on model pages (pre-filled with
  that model as baseline) → links into `/cost`. Rides existing SEO traffic.
- **Privacy:** inputs are typed token counts, never prompt text — V1 is trivially "we never
  see your prompts."

## 5. Education layer

- **Pattern:** evergreen concept prose + **live-data widgets** (small partials/helpers reading
  `PriceCatalog`, e.g. "output is typically N× input — live spread") + a **CTA into `/cost`**
  pre-filled for the concept.
- **Widget placement (build note):** live-data widgets render **only inside explainer pages**
  (and the estimator) — *never on the `/learn` index* or other navigation pages, where they
  duplicate the explainer and blur the page's job. Do not port the index widget from the design
  prototype.
- **Pages:** a `/learn` index — a clean directory (concept cards + a "Start here" featured card
  linking to the foundational explainer; an optional single decorative stat line, not a widget)
  — plus one explainer per concept (extend `PagesController`; `/how-pricing-works`, `/why`,
  `/which-model` already exist and fold in). Indexed, JSON-LD, in the sitemap.
- **Starter set:** (1) how LLM API pricing works; (2) prompt caching; (3) batch processing;
  (4) reasoning / "thinking" tokens; (5) what an AI agent actually costs (the bridge to the
  product); (6) what drives the cost of common features; (7) cost-cutting strategies +
  savings. Ship 1 / 6 / 7 first (largely drafted).
- **Discipline:** small, evergreen, data-backed — not a publishing cadence.

## 6. Demand probes (capture only — the gate's instruments)

- One small table `signal_signups`: `kind` ("measure_interest" | "price_alert"), `email`,
  `payload` (encoded workload/context), `created_at`.
- **"Measure your real usage — notify me"** stub on the estimator (and the agent-cost
  explainer): a locked "coming soon" card + email field → stores `measure_interest`. *This is
  the primary demand signal for the proper product.*
- **"Alert me when this price changes"** on the estimator / model pages → stores `price_alert`.
  (Sending is the product, later.)
- `SignalSignupsController#create` validates email, stores, returns a success partial. No
  sending.

## 7. Views

- `costs/show.html.erb` + `costs/_result.html.erb` — headline spend · savings callout ·
  cross-model board (reuse the `.data` table + provider-square / tier / delta badges) ·
  input/output/cache breakdown · retrospective sparkline · strategy-hint links into the
  explainers · assumptions footer · copy-link + the two probes.
- `learn/index` + explainer templates with live-data partials.
- model page: the embedded estimate widget.
- `signal_signups/_form` + `_success`.

## 8. Tests (`bin/rails test`)

- `CostEstimate`: per-model pricing incl. cache blend; cheapest-fit honours tier + context;
  savings vs baseline; no-fit; retrospective dates ascending.
- `PriceCatalog`: shapes match the catalog; `as_of` correctness.
- `CostsController`: renders; permalink round-trip; frame request returns the frame.
- `SignalSignup`: email validation; create stores the right `kind`.
- (Stimulus stays thin; the math is server-side and covered.)

## 9. Build order (small, shippable steps)

1. **`PriceCatalog` + `CostEstimate` + tests** — the seam + engine, no UI.
2. **`/cost` estimator page + `cost_result` frame + `cost_form`** + the model-page embed.
   *Shippable:* a cross-model estimator with shareable permalinks, riding the index.
3. **Education:** `/learn` + the first explainers (1 / 6 / 7) with live-data widgets +
   estimator CTAs.
4. **Demand probes:** `signal_signups` + the two capture cards.
5. **Public JSON API** (`/api/v1/models.json`) off `PriceCatalog` — near-zero, starts the
   flywheel.
6. Polish to the Claude Design output; wire the gate metrics (§10).

## 10. The gate — what unlocks the proper product

Cheaply measured: estimator **completions** and **permalink shares**; education **organic
entrances** → estimator CTR; and — the decider — the **"measure my real usage" opt-in rate**.
A meaningful measure-opt-in rate is the green light to build §11; alert-opt-ins are the
secondary (retention) signal.

## 11. The proper product (later — recorded, not built)

The trace-ingesting measure-&-optimize tool: client-side trace/CSV ingestion (and
OTel/OpenLLMetry/Langfuse export consumption); the multi-step / agent-loop cost model (tools,
max-tool-calls with growing cache-dominated context, reasoning effort); per-step "where the
money goes" + cheapest-equivalent swaps; batch flagged where latency allows; save/watch + the
alert *pipeline*; optionally a local, aggregates-only CLI / GitHub-App PR cost-check (consume
telemetry, never a proxy). Monetize via Pro/Team + licensed dataset, never affiliate. Reads
prices via `PriceCatalog`; can graduate to its own brand/domain. Design reference:
`DESIGN_BRIEF_V1.md` (now the *product* brief) + the step-list iteration prompt.

---

*Surface for V1: one read seam (`PriceCatalog`), one PORO (`CostEstimate`), one estimator
controller + one Stimulus controller, an education section (mostly prose + small live-data
partials), one tiny signups table, and an optional read-only JSON endpoint. Deliberately
small — the index is the hero.*
