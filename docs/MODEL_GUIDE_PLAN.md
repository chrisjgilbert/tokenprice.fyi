# Model Guide — product plan

*Companion to `PRODUCT_VISION.md` and `V1_BUILD_PLAN.md`. This plan resolves a strategic
question — should the product pivot toward model selection now that pricing-comparison sites
(pricepertoken.com and others) have multiplied — and it tightens the app at the same time.
The answer is a **reframe, not a pivot**: keep the price index as the spine, add a tight guide
layer that helps a developer pick where to start, and cut the sprawl that has accumulated.*

This is the strategy hub. Detail lives in three companion docs:

- **`MODEL_GUIDE_SPEC.md`** — how to build it: the Guide page, the shared `FeaturePattern` data
  structure, and the education layer.
- **`MODEL_GUIDE_COPY.md`** — the copy deck: house style and final strings for every screen.
- **`MODEL_GUIDE_AUDIT.md`** — the pre-build fix list from pressure-testing a design prototype.

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
| **Models** (`/`) | **KEEP — nav** | The price reference. Sort, filter, search. The homepage. Carries a compact **Latest-update widget** (newest launches/price moves with real numbers, links to Trends) — kept deliberately; reads as a dev changelog, not marketing. |
| **Guide** (new) | **BUILD — nav** | Where to start, per job. Pipeline-shaped, sensible options, per-call cost inline. Replaces `/which-model`. (Spec §1.) |
| **Trends** (`/trends`) | **KEEP — signature** | Full price-history chart. The homepage links to it from the Latest-update widget (no separate timeline teaser). |
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

The build detail for the Guide, the shared `FeaturePattern`, and the education layer is in
`MODEL_GUIDE_SPEC.md`.

---

## 4. Open questions / risks

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

## 5. Sequencing

**Phase 0 — Bank the cuts (fast, low-risk, immediately tighter).**
Remove `/map`, `/cost` (as a destination), `/why` (→ footer line); collapse `/learn` from a hub to
a lean landing; drop `/compare` and `/providers/:id` from the primary nav (keep the routes as
generated views). Keep the pricing math from `/cost` as a shared function for the guide.

**Phase 1 — Model the feature patterns, then build the Guide, replacing `/which-model`.**
Define the `FeaturePattern` data (Spec §2) for the launch tasks first — it's the source of truth for
both the guide and the explainer. Then build the guide off it: per task, drivers + pipeline steps +
starting options + inline per-call cost. Port `/which-model` content into it; `/which-model` 301s
to the guide. Add "Guide" to the nav.

**Phase 2 — Wire education + homepage.**
Build the "What an AI feature is actually made of" explainer from the same `FeaturePattern` data,
and lead `feature-costs` with the call-chain. Cross-link explainer ↔ guide. Keep the Latest-update
widget as the homepage's link into the Trends signature page (no separate timeline teaser).

**Phase 3 — Later, only if earned.**
Modality expansion (TTS/image/embeddings data model) and per-step pipeline cost summation. Both
gated on real demand, same discipline as the original cost-tool gate.

Apply the `MODEL_GUIDE_AUDIT.md` fixes as you build — #1–#3 are gating and touch the Guide and the
education layer directly.

---

## 6. Out of scope

A standalone pricing-calculator destination; per-job model rankings or leaderboards; usage-based
rankings (OpenRouter's moat — we lack the traffic); benchmark-score breadth (Artificial Analysis's
moat); modalities beyond text tokens at launch; any backend/account surface for the guide.

---

## 7. What success looks like

- Organic landings on the guide's task pages (the "best model for X" intent we can credibly own).
- The guide → price-table click-through (the guide sends people *into* the index, not away).
- Education pages retained and cross-linked, not orphaned.
- Nav down to 2 primary destinations; no page in the product depends on a fabricated number.
