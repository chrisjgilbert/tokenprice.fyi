# V1 Build Plan — the Cost tool (`/cost`)

*Companion to `PRODUCT_VISION.md` (17 June product definition) and the Claude Design V1
brief. Scope = the **tight V1** only. Everything in the vision's "Deferred to V2+" list
stays deferred. Goal: ship the smallest thing that proves devs find "estimate + measure →
optimize" valuable and shareable, with almost no new infrastructure.*

---

## 1. Principle — reuse the house patterns, add almost nothing

The app already has every pattern V1 needs:

- **Server-rendered ERB + a Turbo Frame** for the live result (the homepage swaps the
  `#models` frame on each debounced form submit via `filters_controller.js`). The Cost
  tool's result panel is the same pattern.
- **Inline SVG charts via a helper** (`ChartsHelper#price_history_chart`). The retrospective
  sparkline is the same approach.
- **Tailwind + CSS custom-property tokens** + per-view `<style>` blocks. Port the Claude
  Design output into this, reusing existing tokens (`--color-indigo-*`, `--font-mono`, …).
- **Tested Ruby (`bin/rails test`)** for all money math; **thin vanilla Stimulus** only for
  local text→number transforms.

No Node build, no accounts/login, no email sending, no SDK, no new model/price fields.

## 2. Privacy architecture (the load-bearing decision)

The "we never see your prompts" promise is kept literally: **prompt text and usage CSVs are
tokenized/parsed client-side; only derived numbers are submitted.**

| Input | Done in the browser (never sent) | Sent to the server |
|---|---|---|
| **Describe** | — | workload profile (token counts, req/mo, cache %, tier, baseline) |
| **Measure a call** | tokenize pasted prompt/output text | the resulting token counts |
| **Import usage** | parse the CSV, match models, aggregate | per-model aggregates (model + token sums + req/cost) |

So the server only ever receives integers and slugs, in query params (which also makes every
estimate a **shareable, indexable permalink**).

## 3. Compute location — server-side, tested

The pricing math is the heart of the product, so it lives in tested Ruby POROs (not JS), and
the result renders into a Turbo Frame — exactly mirroring the homepage. The browser does only
the privacy-preserving text→number work above.

## 4. Backend (small, all tested)

**Routes**
```ruby
get  "cost",       to: "costs#show",          as: :cost
post "cost/alert", to: "alert_signups#create", as: :cost_alert
```

**`CostsController#show`** — decodes the profile *or* import aggregates from params, runs the
PORO, renders the page with the result inside `turbo_frame_tag "cost_result"`. On a frame
request it returns just the frame (same as `models#index`).

**`CostEstimate` PORO** (`app/services/cost_estimate.rb`) — *port of `estimator.js`*:
- Input: `{ sys, fresh, out, req, cache, min_tier, baseline_slug }`.
- For each `AiModel.listed`: `$/request` and `$/month`, with cache blending
  (`inFresh + inCached(hit%) + out`), context-fit flag, tier-eligibility.
- `recommendation` = cheapest model that fits the context **and** meets the min tier.
- `savings` vs baseline (`$/mo`, `%`, `$/yr`).
- `breakdown` = input / output / cache split + cache-saved $/mo.
- `retrospective` = cheapest fitting+eligible model's `$/mo` on each distinct price-change
  date (reuse `AiModel#price_as_of`); used by the sparkline.

**`UsageReprice` PORO** (`app/services/usage_reprice.rb`) — *port of `analyzeUsage`*: given
per-model aggregates `{slug => {in, out, cached, reqs, cost?}}`, compute actual spend (use the
reported `cost` column when present, else price at current rates) + a leaderboard repricing
**all observed tokens** across the catalog. (CSV *parsing* is client-side; only this repricing
is server-side.)

**`AlertSignup`** model + `alert_signups` table (the only new migration): `email`,
`payload` (the encoded workload, so it can seed an alert later), `created_at`. `#create`
validates the email, stores it, returns a success partial. **No sending in V1.**

**`ChartsHelper#cost_retrospective_sparkline(series)`** — small SVG helper in the existing
style.

## 5. Frontend (vanilla Stimulus — no build step; matches existing controllers)

- **`cost_form_controller`** — debounced `requestSubmit` on input change + URL sync; a near-clone
  of `filters_controller`. Drives the `cost_result` Turbo Frame and the permalink.
- **`cost_tokenizer_controller`** — counts tokens from pasted text locally (*port `tokenizer.js`*),
  writes the counts into the profile fields. Raw text is never put in a submittable field.
- **`cost_import_controller`** — parses a pasted/dropped CSV locally (*port `parseUsageCSV` +
  `matchSlug` + `COL` from `blueprint-core.js`*), emits hidden per-model aggregate fields.
- **Mode switch** — a segmented control (Describe / Measure / Import) toggling which subform is
  active; all three write into the same fields the frame reads.

## 6. Views

- `costs/show.html.erb` — nav gains a "Cost" link; input panel (3 modes); `turbo_frame_tag
  "cost_result"` wrapping the result partial.
- `costs/_result.html.erb` — headline spend · savings callout · reprice board (reuse the
  `.data` table + provider-square / tier / delta badges) · breakdown bar · retrospective
  sparkline · strategy hint cards · assumptions + "we never see your prompts" footer · action
  bar (Copy link / Save / Alert me).
- `alert_signups/_form.html.erb` + `_success.html.erb`.
- Reuse existing helpers: provider square, tier/delta badges, `PriceFormat`.

## 7. Tests (`bin/rails test`)

- `CostEstimate`: per-model pricing incl. cache blend; cheapest-fit honours tier floor +
  context window; savings vs baseline; no-model-fits case; retrospective dates ascending.
- `UsageReprice`: aggregation; reprice leaderboard; unmatched models; reported-cost vs derived.
- `CostsController`: `/cost` renders; permalink params round-trip; frame request returns the frame.
- `AlertSignup`: email validation; create stores; bad email rejected.
- Stimulus stays thin (text→number only); the money math is fully covered server-side. One
  optional system test for the happy path.

## 8. Build order (each step is a small, shippable PR)

1. **`CostEstimate` + tests** — the engine, no UI.
2. **`/cost` page + result frame + `cost_form`** (Describe mode: fields/sliders + presets).
   *Shippable:* a working cross-model estimator with shareable permalinks.
3. **`cost_tokenizer`** (Measure mode): paste → counts.
4. **`UsageReprice` + `cost_import`** (Import mode): CSV → reprice leaderboard.
5. **Retrospective sparkline + strategy hints.**
6. **`alert_signups` capture + success state.**
7. **Polish to the Claude Design output** + wire the three signal metrics (below).

## 9. Promising-signs instrumentation (cheap — this is the V2 gate)

Count, privacy-friendly: estimate/measure/import **completions** (by mode), **permalink copies**,
and **alert opt-ins**. Share-rate and alert-opt-in are the two indicators (per the vision) that
say "there's a returning product here" and justify pushing into V2.

## 10. Open decisions (confirm before/while building)

1. **Alert *sending* stays out of V1** (capture only). — assumed; confirm.
2. **"Measure" depth:** V1 = a single prompt/output/call → token counts. Multi-call trace
   reconstruction is V2 (Blueprint territory). — assumed.
3. **LLM "describe" front door deferred:** V1 = fields + example presets + an optional
   client-side heuristic. This sidesteps the BYO-key / API-cost question entirely. — assumed.
4. **Server-side compute (tested Ruby + Turbo Frame)** over a fully client-side tool, to keep
   the money math tested and consistent with the house style. — recommended; confirm.

*Estimated surface: one new table, one controller, two POROs, three Stimulus controllers, two
views — most of it ported from the existing prototypes. Deliberately small.*
