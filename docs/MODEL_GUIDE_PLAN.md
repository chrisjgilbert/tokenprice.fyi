# Model Guide — product plan

*Companion to `PRODUCT_VISION.md` and `V1_BUILD_PLAN.md`. This plan resolves a strategic
question — should the product pivot toward model selection now that pricing-comparison sites
(pricepertoken.com and others) have multiplied — and it tightens the app at the same time.
The answer is a **reframe, not a pivot**: keep the price index as the spine, add a tight guide
layer that helps a developer pick where to start, and cut the sprawl that has accumulated.*

---

## 1. The decision

**tokenprice.fyi is a price reference with a guide layer. Not a pricing calculator. Not a
ranking engine.**

Defining sentence:

> Every LLM API price, normalized and kept in history, with sensible starting points for your
> task — no fabricated bills, no rankings.

What changed and why:

- **The price table is now a commodity.** pricepertoken.com (300+ models, benchmark
  leaderboards, an MCP server), OpenRouter, Artificial Analysis, and a long tail of calculators
  all show current prices. Competing on table breadth is a loss.
- **The white space is decision support.** Provider docs all preach "use the cheapest model that
  clears your quality bar," but no neutral third party operationalizes that. OpenRouter and the
  pricing clones are thin on education; Artificial Analysis is benchmark-first, not
  decision-first. That gap is the natural home of a pricing tool that already has an education
  layer.
- **We already had the seeds of this.** `/which-model` (task→tier prose) and the `/learn`
  explainers are a guide layer that was never surfaced as the product. The work is to elevate and
  structure them, then delete everything that distracts from them.

This is the same gate `PRODUCT_VISION.md` set ("build the cost tool only if the index earns it").
The estimator was a probe. We are deciding the product is the **index + guide**, and retiring the
probe.

---

## 2. Principles (the rules every screen obeys)

1. **No fabricated volume.** Never bake an invented "requests per month" into a headline cost.
   Cost is shown per call for a representative token shape, or as a ratio. The user brings their
   own scale.
2. **No per-job ranking.** The guide offers a few sensible starting options (a cheap default, a
   step-up for quality, an open-weight option). It never publishes a "#1 model for RAG"
   leaderboard — that needs a capability score we can't defend or maintain.
3. **Jobs are pipelines, not single calls.** A chatbot is intent + classification + retrieval +
   generation. The guide treats a job as steps and suggests a starting model *per step*. This is
   the one thing nothing else in the product (or the market) does.
4. **One in, one out.** The guide ships *as* `/which-model`'s replacement. Net page count drops
   even though we add a page.
5. **Education is the differentiator, not filler.** The explainers stay and get cross-linked to
   the guide. They are the moat against thinner competitors.

---

## 3. The tightened product

From ~13 destinations to **2 in the nav**, one signature page, and everything else generated or
plumbing.

| Surface | Disposition | Role |
|---|---|---|
| **Models** (`/`) | **KEEP — nav** | The price reference. Sort, filter, search. The homepage. |
| **Guide** (new) | **BUILD — nav** | Where to start, per job. Pipeline-shaped, sensible options, per-call cost inline. Replaces `/which-model`. |
| **Trends** (`/trends`) | **KEEP — signature** | Full price-history chart. Plus a slim market-event timeline teaser on the homepage that links to it. |
| Model detail (`/models/:id`) | KEEP — drill-down | Per-model profile + its price history. Not in nav; reached from the table. |
| Compare (`/compare`) | DEMOTE — generated view | Kept as a view/URL off the index for "X vs Y" intent. Out of primary nav. |
| Provider (`/providers/:id`) | DEMOTE — generated view | Effectively `/?provider=x`. Kept for entity SEO, not a hand-built destination. |
| **Learn** (`/learn`) | KEEP — lean landing | Slim index of the explainers. Not a heavy "hub." |
| `/how-pricing-works` | **KEEP** | Foundational pricing primer. Per-token billing, input/output, caching, batch. |
| `/learn/feature-costs` | **KEEP** | Cost shape per feature (RAG, chat, classification, summarization, agents). The conceptual twin of the guide. |
| `/learn/cost-cutting` | **KEEP** | Caching, batch, routing, output trimming. Actionable. |
| API (`/api/v1/models.json`) | KEEP — plumbing | Citation/backlink flywheel. Not a nav destination. |
| Sources (`/sources`) | KEEP — plumbing | Trust substrate for the "no fabricated numbers" promise. Footer link. |
| **`/cost`** | **CUT** | Capability becomes an inline per-call cost in the guide. Removes the ranking table, the monthly-bill framing, and the pipeline-pricing problem in one move. |
| **`/map`** | **CUT** | Provider geography is not a step in choosing a model. Country is a column, not a hand-maintained SVG. |
| **`/which-model`** | **CUT → guide** | Same job, prose form. Its content becomes the guide's seed copy. |
| **`/why`** | **CUT → footer line** | Positioning essay, not education. Fold one line into the footer/about. |

What this removes, deliberately:

- The two things the owner disliked — baked volume and per-job ranking — are now structurally
  absent (no estimator, no leaderboard).
- The pipeline-pricing fork disappears: with no `/cost` destination, there is no estimator to
  extend into multi-step billing.

---

## 4. The Guide (the one new build)

**Purpose.** A developer arrives knowing their job ("RAG support bot", "coding agent", "bulk
classification") and leaves knowing where to start — which kind of model for each step, and
roughly what a call costs. Browse-by-task, linkable ("best models for RAG"), volume-free.

**Shape of a guide page (per task):**

1. **What drives cost here** — 2 short paragraphs + 3 cost drivers. Plain declaratives. (This is
   `/which-model` + `feature-costs` content, restructured.)
2. **The pipeline** — the job broken into steps/roles. Example, a RAG support bot:
   - *Retrieve / rerank* — small model, cheap, runs every query.
   - *Generate answer* — mid model, large input (retrieved context), short output.
   Each step names a **starting tier** and 2–3 concrete model options.
3. **Starting options per step** — a cheap default, a step-up for quality, an open-weight option.
   Each shows `≈ $X per call` for the step's representative token shape, and links into the price
   table. No ranking, no scores, no monthly total.
4. **Cross-links** — to the matching `feature-costs` explainer ("why RAG is input-heavy") and to
   the price table filtered to the suggested tier.

**Tasks to cover at launch** (the cost-distinct ones): RAG, coding agent, chatbot,
classification/extraction, summarization, agentic workflow. Translation, synthetic data, and
text-to-speech are candidates but see §6 on modality limits.

**Data it needs.** Because we do **not** rank, the guide needs no numeric capability score — the
single hardest data problem from earlier explorations is avoided. It needs, per task: a
representative per-step token shape, and a small curated set of "starting option" model slugs per
step (cheap / quality / open-weight). That curation is editorial, keyed by model slug, and
maintained in seeds alongside the existing `best_for` / `strengths` / `tier` fields.

**The per-call cost figure.** Computed from the model's current input/output/cached price (already
in the catalog) against the step's representative token shape. Volume-free. This reuses the
pricing math that powered `/cost`; we keep the function, drop the page.

---

## 5. Education

No educational content is lost. Only `/why` (positioning, not teaching) is demoted.

- **Keep** `how-pricing-works`, `feature-costs`, `cost-cutting` as distinct, well-made pages under
  a **lean Learn landing**.
- **Trim only genuine overlap** — if caching is explained in two places, say it once and link.
  Trim duplication, never depth.
- **Cross-link education and the guide.** `feature-costs` teaches the cost shape; the guide applies
  it. The guide's "why this is input-heavy" blurb links to the explainer; the explainer ends with
  "→ see starting options in the guide." They reinforce each other instead of competing.

---

## 6. Open questions / risks

- **Starting-option curation.** Who picks the cheap/quality/open-weight option per step, and how
  often is it refreshed? This is editorial and must stay current as models ship. Lighter than a
  capability score, but a real maintenance commitment. The existing admin tooling + OpenRouter
  sync help.
- **Modalities beyond text.** Text-to-speech, image, video, and embeddings are underserved in the
  market (a genuine opening), but our index prices *text tokens*. TTS is billed per character and
  isn't in the catalog. Decision deferred: either expand the data model (per-character /
  per-image pricing) later, or scope the guide to text-token tasks and be upfront. Launch is
  text-token tasks only.
- **Agents that loop.** The "big generation step dominates the bill" shortcut (which lets us skip
  pipeline summation) breaks for agents that loop many times. If agentic workflows become a focus,
  per-step cost summation is the first thing to revisit.
- **Compare as generated views.** Auto-generated "X vs Y" pages risk thin/duplicate content at
  scale (~40 models = ~780 pairs). Cap to high-demand pairs rather than the full matrix; let
  Search Console data settle it.

---

## 7. Sequencing

**Phase 0 — Bank the cuts (fast, low-risk, immediately tighter).**
Remove `/map`, `/cost` (as a destination), `/why` (→ footer line); collapse `/learn` from a hub to
a lean landing; drop `/compare` and `/providers/:id` from the primary nav (keep the routes as
generated views). Keep the pricing math from `/cost` as a shared function for the guide.

**Phase 1 — Build the Guide, replacing `/which-model`.**
Port `/which-model` content into the structured guide. Per task: drivers + pipeline steps +
starting options + inline per-call cost. `/which-model` 301s to the guide. Add "Guide" to the nav.

**Phase 2 — Wire education + homepage.**
Cross-link `feature-costs` ↔ guide. Add the slim market-event timeline teaser to the homepage,
linking to the Trends signature page.

**Phase 3 — Later, only if earned.**
Modality expansion (TTS/image/embeddings data model) and per-step pipeline cost summation. Both
gated on real demand, same discipline as the original cost-tool gate.

---

## 8. Out of scope

A standalone pricing-calculator destination; per-job model rankings or leaderboards; usage-based
rankings (OpenRouter's moat — we lack the traffic); benchmark-score breadth (Artificial Analysis's
moat); modalities beyond text tokens at launch; any backend/account surface for the guide.

---

## 9. What success looks like

- Organic landings on the guide's task pages (the "best model for X" intent we can credibly own).
- The guide → price-table click-through (the guide sends people *into* the index, not away).
- Education pages retained and cross-linked, not orphaned.
- Nav down to 2 primary destinations; no page in the product depends on a fabricated number.
