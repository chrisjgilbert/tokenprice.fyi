# Model Guide — build spec

*The "how to build it" companion to `MODEL_GUIDE_PLAN.md` (strategy and sequencing). Covers the
Guide page, the shared feature-pattern data structure, and the education layer. Copy lives in
`MODEL_GUIDE_COPY.md`; known prototype issues in `MODEL_GUIDE_AUDIT.md`.*

---

## 1. The Guide (the one new build)

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
text-to-speech are candidates but see the Plan's risks (modality limits).

**Data it needs.** Because we do **not** rank, the guide needs no numeric capability score — the
single hardest data problem from earlier explorations is avoided. It needs, per task: a
representative per-step token shape, and a small curated set of "starting option" model slugs per
step (cheap / quality / open-weight). That curation is editorial, keyed by model slug, and
maintained in seeds alongside the existing `best_for` / `strengths` / `tier` fields.

**The per-call cost figure.** Computed from the model's current input/output/cached price (already
in the catalog) against the step's representative token shape. Volume-free. This reuses the
pricing math that powered `/cost`; we keep the function, drop the page.

---

## 2. The feature pattern (one shared data structure)

The highest-value idea in the guide layer is that **a feature is a chain of calls, each with a
different job** — a chatbot is intent → classify/route → retrieve → generate, not one call. That
insight is *why* you pick a model per step, *why* the cheap step and the smart step are usually
different models, and *why* per-token sticker prices don't tell you what a feature costs.

We model it **once, as data**, so the same source drives both the guide and the education
explainer (below) and they can never drift apart. A feature pattern is an ordered list of steps:

```
FeaturePattern:
  key        # "chatbot", "rag", "agent", "classification", ...
  label      # "Support chatbot"
  blurb      # one line: what it is
  steps: [
    {
      role          # "intent", "retrieve/rerank", "generate", "plan", "tool-call", ...
      purpose       # one clause: what this call does
      tier          # starting tier for this step: small | mid | frontier
      shape         # representative per-call token shape {sys, in, out}
      cost_driver   # is this step where the money concentrates? (bool / note)
      capability    # is this the step that actually needs the capable model? (bool / note)
      loops         # does this step repeat? (e.g. agents) — flag, not a number
      options       # 2–3 curated model slugs: cheap / quality / open-weight
    }, ...
  ]
```

The two payoff fields are `cost_driver` and `capability`: they're often **different steps**, and
that mismatch is the thing developers get wrong (one frontier model for the whole chain when only
the generate step needed it). The guide and the explainer both render straight from this — the
guide as an interactive per-step view with inline per-call cost, the explainer as a worked
call-chain diagram. One edit updates both.

> Build both surfaces from this one source. The prototype audit (`MODEL_GUIDE_AUDIT.md`, #2) found
> the guide and explainer drifting because they were hand-maintained copies — this structure is
> exactly what prevents that.

---

## 3. Education

No educational content is lost. Only `/why` (positioning, not teaching) is demoted.

- **Keep** `how-pricing-works`, `feature-costs`, `cost-cutting` as distinct, well-made pages under
  a **lean Learn landing**.
- **Add the foundational explainer: "What an AI feature is actually made of."** Teaches the
  feature-pattern idea (§2) generally, then shows worked call-chains — chatbot, RAG, agent, bulk
  classification — and for each, which step dominates cost and which step actually needs the
  capable model (usually not the same step). This is the concept the whole guide layer stands on,
  and it's genuinely shareable/SEO-friendly ("how many LLM calls does a chatbot actually make").
  It renders from the same `FeaturePattern` data the guide uses.
- **Fold the pipeline anatomy into `feature-costs`.** `feature-costs` currently answers "where does
  the money go in feature X"; lead it with the call-chain first ("a feature is several calls"),
  then show where cost concentrates *in that chain*. These are close cousins — consider whether
  they become one stronger piece rather than two. Trim overlap, never depth.
- **Keep the live-data widgets.** The existing explainers embed live pricing (`io_ratio_widget`,
  a live frontier-model example). Education backed by live data is the differentiator — preserve it
  in the rebuilt pages (audit #3).
- **Cross-link education and the guide.** The explainer teaches the pattern; the guide applies it
  to a specific job. The guide's "why this is input-heavy" blurb links to `feature-costs`; the
  explainer ends with "→ see starting options in the guide." They reinforce each other instead of
  competing.
