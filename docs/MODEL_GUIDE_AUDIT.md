# Model Guide — pre-build fix list (from the design-artifact audit)

*Companion to `MODEL_GUIDE_PLAN.md`. A clickable design prototype of the plan was built and
pressure-tested by five adversarial auditors (cost-lens, scope/IA, pipeline integrity, voice/design
system, education degradation). The direction held up — no fabricated volume, tightened scope, and
pipelines / no ranking all passed, and the pipeline insight proved real across all six tasks (the
Agent task has its cost driver on a small-tier step while the capable-model steps are elsewhere —
not a chatbot contrivance). The issues below are execution-level, recorded so the build starts from
them rather than rediscovering them.*

Two of the findings confirm concerns raised during planning: the per-call cost lens has one real
leak (the asymmetric cache discount, #1), and the education comes out thinner than today unless
deliberately preserved (#3).

## Gating (touch the centerpiece — fix before/with the build)

| # | Severity | Issue | Fix |
|---|---|---|---|
| 1 | FAIL | In the guide, only the "cheap default" option was priced with a 50% cache discount; the step-up and open-weight options got none, all shown as comparable "≈ $X per call" with no label. Understates the cheap option ~22%+ on input-heavy steps — a misleading comparison in the centerpiece. A latent bug compounds it: models with no published cache rate fall back to the full input rate. | Price every option on the **same cache assumption** (default none), or keep a discount but **label it** ("$X cached"). Gate any cache discount on `cached != null` so a model without a cache rate can never appear discounted. |
| 2 | FAIL | The guide's pipeline data and the anatomy explainer's call-chains were **two hardcoded copies that already disagreed** (the "Verify" step was mid-tier in one, small in the other; the explainer's "agent" diagram was actually the coding pipeline, so the real agent loop never appeared). This is exactly the drift the shared `FeaturePattern` exists to prevent. | Build both surfaces from the **one `FeaturePattern` source** (see `MODEL_GUIDE_SPEC.md` §2). The explainer projects `{role, tier, cost_driver, capability}` off the same step objects. Fix the coding/agent mislabel so the explainer shows the actual agent loop. |
| 3 | FAIL (directional) | The anatomy explainer **replaced** `feature_costs`' worked cost-breakdown tables (78% input, 30× tier gap, $80 vs $2,400/day) with a numbers-free call-chain diagram, and the **live price widget** (`io_ratio_widget`) — education backed by live data, our differentiator — was absent from the whole Learn area. Stub cards for the other explainers are fine for a mock; this is the directional loss to avoid. | Make the anatomy explainer the **on-ramp to** `feature_costs`, not a replacement — keep the worked tables and the "where the bill concentrates" analysis. **Port `io_ratio_widget`** (and a live frontier-model example) into the rebuilt explainers, wired to the real `PriceCatalog`. |

## Non-gating (correctness + polish)

| # | Severity | Issue | Fix |
|---|---|---|---|
| 4 | Bug | A task with a cost-driver step but **no** capable-model step (summarization) rendered a broken takeaway — "…the steps that need the capable model (****) are different" with an empty name. | Branch the takeaway copy when there is no `capability` step; don't assert a driver≠capability contrast that doesn't exist. |
| 5 | Weak | The RAG "embed query" step was priced as a chat completion. Embeddings are a **separate endpoint** with their own pricing the catalog doesn't carry, so the per-call cost was fabricated. | Drop the embed step from the *priced* pipeline (it's plumbing, like vector search), or label it "not priced here — separate embeddings endpoint." Reinforces the text-token-only launch scope (Plan risks). |
| 6 | IA | The homepage buried the price index under **two overlapping "recent activity" modules** (a changelog panel and the market-event strip), both funnelling to Trends — three Trends entry points and four hero CTAs before the table. The one place the tightening didn't land. | **Decided:** keep the **Latest-update widget** (the substantive one — real numbers, links to Trends); **drop the market-event timeline strip** (thin, redundant). One Trends entry point. Keep the widget compact so the table isn't pushed far down; trim hero CTAs to two (Guide + Learn). |
| 7 | Voice | ~5 marketing/chatbot/rhetorical slips, concentrated in the guide and Learn headers: a rhetorical question ("Want the model behind this?"), "No fluff, no funnel… it reframes how you think about cost", "The model guide that knows what it costs" (personification), two dramatic em-dashes, and "frontier-adjacent quality" (vague, unmeasurable). | Rewrite to plain declaratives per the CLAUDE.md copy rules (the finalized strings live in `MODEL_GUIDE_COPY.md`). |
| 8 | Token | One price rendered in the sans UI font instead of mono/tabular; footer copy said "40+ models" while the catalog held 29. | Every price/date/count is mono + tabular. Keep marketed counts consistent with the data (see Copy: dynamic count). |

## What explicitly passed (don't relitigate)

No fabricated volume anywhere (no requests/month, no monthly or annual total); per-call is the
consistent decision lens, `$/1M` only on the index where it belongs. Nav is exactly Models · Guide
· Trends · Learn; every cut page (`/cost`, `/map`, `/why`, `/which-model`, the `/learn` hub) is
genuinely gone; compare/provider are not destinations. Jobs are real pipelines with no model
ranking, and the six tasks have genuinely distinct cost shapes. Design tokens match the live app.
