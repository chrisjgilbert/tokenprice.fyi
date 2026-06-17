# tokenprice.fyi — Product Vision

*The live price index for LLM APIs — understand and compare what every model costs, and price your own usage against all of them.*

## What this is

tokenprice.fyi is a **price index for LLM APIs**: it normalizes what every model from every provider costs, tracks how those prices move over time, and explains how API pricing actually works — so a developer can understand, compare, and roughly price their own usage in one place.

That index is the foundation for a second, later product: a tool that **measures what a developer's *actual* AI feature costs** — grounded in their real calls — and shows them, neutrally, where they're overpaying and the cheapest equivalent across every model.

Two products, one shared data backend. **Build the index first; build the cost tool only if the index earns it.**

## The opportunity

The market reprices constantly — frontier prices have fallen ~99% since GPT-4, with double-digit cuts several times a year — yet almost nobody re-evaluates their model choice after shipping. Developers decide model and budget in the dark: they see sticker prices but can't translate them into "what my feature will cost," so they default to expensive frontier models for tasks a model 20× cheaper would handle.

Two things in this space are already commodities, and one is wide open:

- **The price table is a commodity.** OpenRouter, artificialanalysis, llm-prices.com, and every provider's docs show current prices. Most people arrive from Google, get their number, and leave.
- **Measuring your own spend is a commodity too.** Langfuse, Helicone, LiteLLM, Portkey, Vantage, and CloudZero already capture calls and report cost, with far broader scope (tracing, routing, budgets) than a side project could match.
- **Neutrally *optimizing across models* is wide open.** Everyone reports what you *did* spend. Almost nobody answers *"what would this exact workload cost on every **other** model — at today's and historical prices — what's the cheapest equivalent, and tell me when that changes."* That's a price-data problem, and the answer is the moat.

## The moat

A **sourced, dated, append-only price history across every provider** — ~80 models back to early 2023, each snapshot carrying its source. Most competitors store "today's price" and discard history. This record is the one asset that's hard to copy, and it does real work:

- it makes any estimate **current and trustworthy** — a shared number recomputes at today's prices, which no static calculator does;
- it lets us **price a workload through history** ("already 40% cheaper than a year ago");
- it's the only thing that can detect *the moment a price moves* — the trigger for "tell me when my answer changes."

We never compete on model **quality**. Benchmarks are an arms race against funded leaderboards, they go stale, and they're off-brand for a neutral price source. **We lead with cost — the one axis we can be authoritative on — and treat quality as a tier floor, never a score.**

## Neutrality is the wedge

We **sell no inference and take no referral fee.** That's the one thing the gateways and FinOps tools structurally can't claim, and it's what makes our advice trustworthy enough to act on. Every recommendation is "cheapest equivalent by price," never "the model that pays us."

## Two products, one backend

**1. tokenprice.fyi — the price index (build now).**
*"Understand and compare LLM API pricing — then roughly price your own."* The reference data, an education layer, and a lightweight estimator. This is the funnel (SEO + citation) and the moat (the history). Low-maintenance; compounds passively.

**2. The cost product (build later, if signs justify).**
*"Know what my feature actually costs, and cut it."* A neutral cross-model cost-optimization tool fed by a developer's real traces and usage. The differentiated, monetizable product.

**The seam between them:** the cost product reads price data only through a defined interface — a `PriceCatalog` service and a public JSON API — never ad hoc. That one decision (a) keeps the two cleanly separable, (b) *is* the "free API → licensed dataset" monetization, and (c) lets the product later move to its own brand/domain as a packaging change, not a rebuild. It also keeps other data sources possible, since the product depends on the interface, not our table.

## Operating principles

- **Estimate and measure are one grounding ladder**, trading friction for fidelity: *describe in words* → *paste a real prompt/trace* → *import a usage CSV* → *consume telemetry*. The same optimizer consumes all of them; V1 only does the first (typed inputs).
- **We never see prompts.** When the product ingests real calls, tokens are counted client-side and only counts and costs are sent — a privacy feature and a major de-scope (no trace store, no PII, no compliance load).
- **Cost-led honesty.** Every number states its assumptions; a cross-model "what-if" reprices the *same tokens* and is labelled a cost comparison, not a quality verdict ("validate with your eval").
- **Owner attention is the scarce resource.** This is a side project. Favour build-once-compounds surfaces (SEO pages, education, shareable permalinks, a free API) over maintenance treadmills — the market-events/news pipeline stays as quiet chart context, never a headline; the map page is buried.
- **Don't rebrand on a guess.** Keep the clean, fast, info-style aesthetic for the reference pages (it's an SEO asset); give the product its own polish under `tokenprice.fyi/cost` (or a subdomain). Split into a separate brand/domain only once the product proves itself — you'll know the right name by then.

## V1 — the index, done well

Tight and low-investment. The index is the hero; education makes it a destination; the estimator is a demand probe. Four legs:

1. **Reference data.** The normalized price table, model/provider pages, the price-history trends chart, and a market-event timeline — polished. The authority surface that ranks and gets cited.
2. **Education (a core pillar).** Evergreen explainers of how LLM pricing actually works — each written once, kept fresh by **embedded live data**, and ending in a **CTA into the estimator, pre-filled for that concept**. Starter set: (1) how API pricing works (input/output/cached units; why output costs more); (2) prompt caching; (3) batch processing; (4) reasoning/"thinking" tokens; (5) what an AI agent actually costs (context accumulation over tool loops); (6) what drives the cost of common features (RAG, chat, classification, summarization, coding agents); (7) cost-cutting strategies and what they save. This is what turns a commodity table into a place worth returning to and citing.
3. **A lightweight estimator.** Single-workload: describe-in-a-sentence or sliders → cost across every model → a **cheapest-equivalent savings** callout → a "priced through history" sparkline → a shareable permalink. Embedded as a compact card on every model page so it rides existing traffic. Its differentiator is *cheapest equivalent on always-current, history-backed prices* — not the arithmetic. Reads prices through `PriceCatalog`.
4. **Two demand probes (capture only).** A **"measure your real usage — notify me"** stub (the primary signal that the second product is wanted) and an **"alert me when this price changes"** capture. No measurement and no sending are built; the opt-in itself is the data.

Nothing here needs new infrastructure beyond a tiny email-capture table — no accounts, no LLM on the critical path. Detailed in `V1_BUILD_PLAN.md`.

## The gate — what unlocks the second product

Cheaply measured: do people **complete and share** the estimator, do education pages **draw organic traffic** that clicks into it, and — the decider — do they **opt into "measure my real usage"** at a meaningful rate? That opt-in rate is the direct demand signal for the trace-ingesting product; alert opt-ins are the secondary, retention signal. Until the gate is met, the index + education + estimator stand on their own as the funnel and the moat.

## The second product (later)

When the gate is met, build the neutral cross-model cost-optimization tool:

- **Ingest real usage** — paste a trace, import a usage CSV, and later consume OpenTelemetry `gen_ai.*` / OpenLLMetry / Langfuse exports. Tokenized client-side.
- **Measure and optimize** — model a real workload, including the things that actually drive bills: tool definitions as per-call input, agentic loops where context accumulates and caching dominates, and reasoning effort billed as hidden output. Show per-step "where the money goes," the cheapest-equivalent swap for each step, and flag batch processing where latency allows.
- **Save, watch, alert** — save a workload and get told when a price move or a new model changes its cheapest answer.
- **A code-level path** — a lightweight, local, aggregates-only CLI or GitHub-App PR cost-check ("this change adds ~$X/mo; the review step could use a cheaper model, −60%"), built by *consuming* telemetry, never by becoming a production proxy.

This product can graduate to its own brand and domain; it still reads prices through the same `PriceCatalog` seam.

## How it makes money

In rough order of cleanliness, none of which compromises neutrality:

1. **A free JSON API → a licensed historical dataset.** The free current-price API seeds a citation/backlink flywheel; the dated, sourced history is the paid product that analysts, finance teams, and tool-builders buy. The moat, monetized directly.
2. **A thin Pro/Team tier** on the second product — saved workloads, price-move alerts, team sharing. No API keys, no spend dashboards.
3. **Opportunistic consulting** — "cut your AI bill" engagements. Doesn't scale, which is fine for a side project; highest $/hour.

## What we deliberately don't do

- **Quality benchmarks** — an arms race; off-brand. Link out instead.
- **An inference gateway/proxy** or key management — that's OpenRouter, and it forfeits neutrality.
- **A general observability/FinOps platform** — crowded, broad, not a side-project shape.
- **Spend dashboards that need customers' API keys** — heavy trust; revisit only with an audience.
- **Affiliate or sponsorship that touches rankings** — neutrality is the whole asset.
- **A content/news treadmill** — education is a small, evergreen, data-backed set, not a publishing cadence.
- **A rename or full rebrand before the product is proven.**

## Where things stand today

A Rails 8 app (SQLite, server-rendered, Tailwind, zero-JS-framework): the normalized price table, model/provider pages, head-to-head compare, a price-history trends chart with market-event overlays, and editorial pages (`/why`, `/which-model`, `/how-pricing-works`, `/sources`). ~80 models with sourced price history to early 2023, a daily OpenRouter sync keeping current prices fresh, and an admin for curation. A hi-fi design system and prototypes exist for the next surfaces. The immediate work is V1: the `PriceCatalog` seam, the single-workload estimator, the education layer, and the two demand probes.
