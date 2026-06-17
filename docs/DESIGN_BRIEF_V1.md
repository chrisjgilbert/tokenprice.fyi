# Design brief — V1 "Cost" tool (for Claude Design)

*The brief to hand to Claude Design to produce the V1 design. Pairs with
`PRODUCT_VISION.md` (17 June product definition + V1 scope) and `V1_BUILD_PLAN.md`
(the Rails implementation plan). Everything here is deliberately scoped to the tight V1;
anything in the vision's "Deferred to V2+" list is out of scope.*

---

## Build on what you already designed

You previously designed tokenprice.fyi: a hi-fi design system + HTML/CSS/vanilla-JS
prototypes (the `design_handoff_tokenprice/` README, the index/model/provider/compare/
trends/learn pages, and the newer `estimate.html` "Cost Studio" and `blueprint.html`).
REUSE THAT EXACT DESIGN SYSTEM — tokens, type (Space Grotesk for UI, JetBrains Mono for
all numerics, tabular), the indigo/slate palette, tier/I-O/status/delta badges, provider
squares, sortable tables, popovers, the brand mark, the faint grid texture, and the
motion rules. I'm attaching that bundle; treat it as the source of truth for look, feel,
and components. Match it in spirit, pixel-for-pixel.

## What V1 is

tokenprice is becoming the NEUTRAL CROSS-MODEL COST-OPTIMIZATION LAYER for developers:
"know what your AI feature costs, and where you're overpaying — grounded in your real
calls and priced against every model."

V1 is ONE new surface — the COST tool — that CONSOLIDATES the strongest parts of
`estimate.html` (Cost Studio) and the Import/Measure logic from `blueprint.html` into a
single coherent page, and DROPS Blueprint's multi-step pipeline builder and the Ask chat.
Think: "Cost Studio, plus two higher-fidelity ways to ground the numbers, minus the
pipeline complexity."

The defining idea: THREE ways to ground a workload (trading friction for fidelity),
feeding ONE optimizer output.

## The page: `/cost` — "What does your AI feature really cost?"

Single, shareable, server-render-friendly page (state in URL params; no SPA). Sticky nav
as existing, with "Cost" added. Structure, top → bottom:

### A. Input panel — a segmented control with three modes

1) DESCRIBE (default; the no-friction / SEO on-ramp)
   - A textarea: "Describe your AI feature — e.g. 'support bot over our docs, 5k chats/day,
     3 turns each'" + example chips + a primary "Estimate cost" button.
   - Reveals the editable workload profile (reuse Cost Studio's fields): system/reused
     tokens, fresh input tokens, output tokens, requests/month, cache-hit % slider,
     minimum-capability tier (Any / Small+ / Mid+ / Frontier), and a "compare against"
     baseline model selector. All pre-filled with sane defaults; the textarea fills them in.
   - An LLM may fill the profile from the text, but design for an instant heuristic
     fallback — never a blocking spinner that can dead-end.
2) MEASURE A CALL (the "Prompt Cost Lab" — zero-setup real measurement)
   - A large textarea to paste a prompt, an example output, or a JSON/labelled agent trace;
     a "Measure" action; a "try a sample" link.
   - Result: the detected/selected model + the REAL measured token counts (system/reused,
     fresh, output, cached) as editable chips that flow into the same workload profile.
   - Trust line: "Counted locally in your browser — we never see your prompt text."
3) IMPORT USAGE (the V1 measure workhorse)
   - A paste box / file drop for a provider usage-export CSV; a small "how to export from
     OpenAI / Anthropic / Google" helper popover; a "try a sample CSV" link.
   - On parse: a confirmation summary (rows recognised, models matched, any unmatched),
     then it flows into the output as ACTUAL spend + reprice.

All three modes share the SAME result panel below; switching modes re-grounds the optimizer.

### B. Output panel — the optimizer (the value; identical regardless of input mode)

- HEADLINE SPEND: big mono $/month (plus a quieter $/request, and "actual $" when imported)
  for the recommended/baseline model.
- RECOMMENDATION + SAVINGS CALLOUT (the screenshot artifact): "Cheapest that fits your
  needs: [provider square] Model — $X/mo · save $Y/mo (−Z%) vs [baseline] ($…/yr)." If
  already cheapest, say so plainly.
- REPRICE BOARD: every model ranked by cost for THIS workload — provider square + name +
  tier badge + context-fit flag + cost bar + $/mo + $/call + delta-vs-baseline pill;
  "cheapest good-enough" row highlighted; no-fit models flagged ("context too small");
  baseline row marked. (Reuse Cost Studio's board styling.)
- WHERE THE MONEY GOES: input/output(/cache) split bar + a cache-savings line ("caching at
  N% saves $…/mo"); for imported data, show each model's share of ACTUAL spend.
- PRICED THROUGH HISTORY (the moat): the retrospective sparkline — "this workload, on the
  cheapest model that fit, over time — −X% since [date] · see what drove the drops →"
  (links to trends/timeline).
- STRATEGY HINTS: 2–3 compact, contextual cost-cutting cards (prompt caching, batch API,
  model routing/tiering, shorter outputs) — reuse Learn's strategy-card styling, condensed.
- ASSUMPTIONS FOOTER: token≈char ratio, the price dimensions used, what's excluded; the
  cost-led caveat ("same tokens, repriced — a cost comparison, not a quality verdict;
  validate a cheaper model with your own eval"); and a persistent "we never see your
  prompts — token counts only" trust line.

### C. Action bar (in/near the result)

- COPY LINK — permalink encoding the workload (URL state).
- SAVE SCENARIO — local (localStorage), shown as a small saved-scenarios list.
- ALERT ME WHEN THIS CHANGES — an email field + button: "We'll email you when a price move
  changes this bill." (V1 captures the email + scenario and shows a success state; actual
  sending and any inbox/management UI are out of scope.)

## States to design

Initial/empty (each mode), loading (describe/measure parse), parse error (bad CSV /
unparseable trace — helpful message + sample), no-model-fits (request exceeds every context
window → guidance), single-result, and the saved/alert success states. Honor the existing
empty-state and error patterns.

## Reuse / consistency

- All components, tokens, and motion (entrance reveals, count-ups, FLIP on reorder, all
  gated by prefers-reduced-motion) and copy tone from the existing system.
- Numerics in JetBrains Mono, tabular; prices formatted as in the prototypes.
- Data contract: reuse the existing Model / PricePoint / Provider shapes from the handoff.
  No new entities required for V1.
- Progressive enhancement (the existing zero-framework house style); responsive per the
  existing breakpoints; mobile-first input panel.

## Explicitly OUT OF SCOPE for V1 (do NOT design)

- Blueprint's multi-step pipeline builder (roles, per-step models, fan-out) — V1 is
  single-workload only (its per-step "where the money goes" idea is honored by the simpler
  input/output split above).
- The Ask chat.
- Any email inbox / alert-management UI, accounts/login, or settings — only the alert opt-in.
- Redesigning index/model/provider/trends/timeline/insights — they stay; just link the Cost
  tool to/from model pages and add "Cost" to the nav.
- Any CLI / GitHub-App / SDK / telemetry surface — that's a later bet, not V1.

## Deliverables

Same format as your previous handoff: a hi-fi, responsive HTML/CSS/vanilla-JS prototype of
`/cost` (reusing the shared design-system files), covering all three input modes and every
state above, plus a short screen-by-screen note (layout, interactions, states, data wiring)
so it can be rebuilt in Rails + Tailwind + Stimulus. Keep it tight — this is a focused V1,
not the whole app.
