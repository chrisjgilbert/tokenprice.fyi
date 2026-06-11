# tokenprice.fyi — Product Vision & Review

*Product review conducted June 2026. Grounded in the current codebase: Rails 8 server-rendered app, SQLite, ~50 curated models across 9+ providers, append-only price history, daily OpenRouter sync, admin-curated Anthropic data.*

---

## 1. Strengths

**The data model is the best thing about this product, and it's genuinely good.** Prices are an append-only dated history (`PricePoint`), not a mutable number. Every snapshot carries `source` and `note` provenance. Curated data is never clobbered by the automated sync. This is the architecture of a *record of record* — most competitors store "current price" and throw history away. If LLM pricing data ever matters as a dataset, this design is the moat-in-waiting.

**Price history + market events is a real differentiator today.** Nobody else shows "DeepSeek cut prices 75% on this date, here's the chart, here's what else happened that week" in one view. The trends page with launch/market event overlays is the closest thing this product has to a unique artifact. Provider pricing pages show *now*; this shows *trajectory* — and in a market where prices moved double-digit percentages multiple times a year, trajectory is decision-relevant ("should I wait?", "does this provider habitually cut prices post-launch?").

**Normalization is quietly valuable.** Every provider quotes pricing differently (per 1K, per 1M, cached vs. not, tables buried in docs). One table, one unit ($/Mtok), one blended sortable number is exactly the "I just need to compare" job. The 3:1 blended metric is opinionated and documented — good — even if the fixed ratio is a weakness (see below).

**The engineering posture fits the product.** Server-rendered, zero-JS-framework, inline SVG charts, JSON-LD, sitemap, canonical URLs: this is built to win SEO queries like "claude opus 4.8 pricing" — which is how 90% of users will arrive. Fast, indexable, cheap to run. Correct call.

**Data hygiene as editorial stance.** "Anthropic figures are authoritative; others are best-effort with sources recorded" is honest in a way that builds trust. The sync's refusal to guess tiers (imports land in `mid` for human re-curation rather than polluting the frontier ranking) shows the right instinct: curation over automation when accuracy is the product.

## 2. Weaknesses & Gaps

**Bluntly: the current product is a very well-built pricing table, and pricing tables are a commodity.** OpenRouter (the upstream data source!), artificialanalysis.ai, llm-stats, Simon Willison's llm-prices.com, and every provider's own docs all show current prices. Anyone arriving from Google gets their number and leaves in 40 seconds. There is no reason to return, no account, no alert, no saved state, no API. **Today the product has zero retention surface and a thin defensible position.** The history data is defensible; the table is not.

Specific gaps, in rough order of how much they hurt:

- **$/Mtok is the wrong unit for decisions.** Nobody budgets in millions of tokens. They budget in "support tickets classified per month" or "documents summarized per day." The product makes users do the multiplication that *is* the hard part. This is the single biggest gap between what the product shows and what users need.
- **The pricing model itself is incomplete.** Real bills include batch API discounts (~50%), prompt-cache *write* costs (cache read is shown, write is not), thinking/reasoning tokens billed as output, image/audio tokens, and tiered or volume pricing. A comparison that omits batch pricing can be off by 2x — enough to flip a model decision.
- **No quality dimension.** Price without capability is half a comparison. A user choosing between a $0.30 model and a $15 model isn't asking "which is cheaper" — they're asking "is the cheap one good enough for *my task*?" The tier taxonomy (frontier/mid/small) is a start but it's a supply-side label, not a task-fit answer.
- **The fixed 3:1 blend silently misranks models for many workloads.** RAG/classification workloads are 20:1 input-heavy; generation workloads are near 1:2. A model with cheap input and expensive output can rank above or below a rival depending entirely on this hidden assumption. The footnote disclaims it, but a footnote doesn't fix a ranking.
- **Compare is capped at two models and has no workload context.** Real shortlists are 3–5 models, and the question is "at *my* token mix and volume, what's the monthly delta?"
- **No alerts, no feed, no API.** The data updates daily but users have no way to be told when something changes. A price cut — the product's most valuable event — currently reaches zero people proactively. There's no JSON endpoint, so nobody can build on the data, which is how reference resources usually become canonical.
- **Coverage trust is fragile beyond Anthropic.** "Best-effort, may lag" is honest but it's also the thing a paying or deciding user can't tolerate. There's no per-model "last verified" timestamp shown, no link to the provider's source page on each price point in the UI.

**Friction summary for a user making a real decision:** they can see prices, but they must bring their own token estimates, do their own arithmetic, guess at quality equivalence, mentally adjust for batch/caching, and re-check manually next month. The product answers "what does a million tokens cost?" when the user's actual question is "what will *this feature* cost me, and on which model?"

## 3. Core User Problem

> **LLM API costs are decided in the dark.** A developer choosing a model can see sticker prices but can't translate them into "what my workload will cost," because cost is a function of price × token volume × traffic shape × discounts (caching, batch) × model choice — and every one of those variables is opaque before launch, fuzzy during build, and tedious to re-derive every time prices move or a new model ships. The result: teams over-pay by defaulting to frontier models for tasks a model 20x cheaper would handle, or under-build by fearing costs they never actually quantified — and almost nobody re-evaluates after launch, even as the market reprices around them monthly.

The user is a developer, founder, or platform/infra lead at a team shipping LLM features. They make a model decision a handful of times a year, but the decision is high-stakes (it compounds with usage) and high-churn (the right answer changes every quarter). They need three things at three moments:

1. **Before building:** "Given my use case, what would this cost per month on each candidate model?"
2. **While building:** "Which is the cheapest model that's good enough for this task?"
3. **After launch:** "Tell me when the answer changes" — a price cut, a new model, a cheaper equivalent.

The current product partially serves moment 2 and ignores moments 1 and 3. The vision is to own all three.

## 4. Model Selection Guidance

**Yes — this is the highest-value editorial layer the product could add, and it should be framed as cost-fit, not benchmark rivalry.** Don't try to out-benchmark artificialanalysis.ai or LMArena; that's a different (expensive) product and an arms race. The framing that fits this product: **"What's the cheapest model that's good enough for this job?"** — selection as a *cost-optimization* question, which is the lens the product already owns.

**How I'd frame it: task profiles, not model reviews.** Curate 8–12 canonical task archetypes that cover most real workloads:

| Task profile | Typical token shape | Tier needed |
|---|---|---|
| Classification / routing / moderation | tiny in, tiny out, huge volume | small |
| Data extraction to JSON | medium in, small out | small–mid |
| RAG answering over docs | large in (cacheable), small out | mid |
| Long-document summarisation | very large in, medium out | small–mid (revised Jun 2026: cheap long-context models cover routine summaries; mid+ for high-stakes documents) |
| Customer-facing chat | medium in/out, quality-sensitive | mid–frontier |
| Code generation / agentic coding | large in (cacheable), large out | frontier |
| Multi-step agents / tool use | huge in via loops, caching critical | frontier + cache pricing |
| Deep reasoning / analysis | medium in, large out incl. thinking tokens | frontier |

Each profile page says: here's the token shape, here's which pricing dimension dominates (this is non-obvious and genuinely useful — e.g. *for agents, cached-input price matters more than headline input price*), here are the 3–4 cost-optimal models at each tier with a per-1K-tasks cost, and here's the "you could drop a tier if…" guidance.

**How I'd build it (fits the stack):**
- A `TaskProfile` model: name, token-shape parameters (avg input/output/cached tokens per task), minimum tier, narrative. Admin-curated like everything else — curation is already this product's operating model.
- Each profile renders a ranked table computed from live pricing: *"Classification, per 1M requests: Model A $40 · Model B $55 · Model C $310."* The numbers stay fresh automatically because they derive from `PricePoint`s; only the shapes and tier judgments need human maintenance.
- These pages are SEO gold ("cheapest model for summarization 2026") and feed directly into the calculator (section 5) — pick a profile, get pre-filled estimates.

**Be honest about the limit:** "good enough" judgments are editorial opinions and will sometimes be wrong. Ship them as opinions with reasoning ("we put this at mid-tier because extraction accuracy plateaus above it for typical schemas"), date-stamped and revisable. An opinionated, dated, transparently-reasoned guide beats both silence and fake benchmark precision — and opinionated curation is already the brand.

## 5. Cost Estimation Tooling

The calculator is the bridge from "pricing table" to "decision tool." What a genuinely useful one looks like:

**Input layer — meet users where their knowledge is.** Most users don't know their token counts; forcing token inputs kills the tool. Offer three entry modes, best-guess defaults everywhere:

1. **Task-profile mode (default):** pick a profile from section 4 → token shape pre-filled → user supplies only volume ("10k requests/day").
2. **Plain-language mode:** "average prompt ≈ 2 pages, response ≈ 3 paragraphs, plus a 1,500-word system prompt" → convert via ~4 chars/token. Approximation is fine; the answer needs to be right within ±30%, not ±3%.
3. **Power mode:** raw input/output/cached tokens per request, cache hit rate, batch share — for people who have production numbers.

**Output layer — a monthly bill, side by side.** For every model (or a chosen shortlist): estimated $/month, $/task, with the three big levers shown explicitly: *with prompt caching* (huge for agents and RAG), *with batch API* (huge for offline workloads), and a sensitivity band ("if usage is 2x your estimate: $X"). The killer row is the delta: **"Switching from Model A to Model B saves $1,840/mo (−62%)."** That sentence is what gets screenshotted into a team Slack — which is the distribution loop.

**Three product properties that make it durable rather than a toy:**
- **Shareable, permalink-able URLs** (`/calculator?profile=rag&volume=300k&models=…`). The artifact people paste into planning docs and PRs. Server-rendered Rails makes this trivial — state in query params, zero JS framework needed.
- **Estimates stay live.** Because results derive from `PricePoint`s, a saved/shared estimate recomputes at today's prices — "your February estimate is now 18% cheaper." No competitor's static calculator can do this; it's the history architecture paying off.
- **Honest arithmetic.** Include cache-write costs, thinking-token output billing, and batch discounts, with assumptions stated inline. The product's trust positioning ("sources recorded, Anthropic authoritative") should extend to its math.

A second, smaller tool falls out for free: **per-task price** as a first-class unit alongside $/Mtok ("a 50-page-document summary on this model ≈ $0.11"), shown on model pages. It reframes the entire site from token prices to task prices.

## 6. Differentiation — Becoming the Definitive Resource

A pricing table can't be defended. Four assets can:

1. **The historical record.** Already being accumulated and nobody else does it properly. Double down: per-price-point source links surfaced in the UI, "last verified" timestamps on every model, an auditable changelog page ("every LLM price change, dated, sourced"). Become the dataset journalists, analysts, and finance teams cite. *Trust + freshness, compounding daily.*
2. **A free JSON API + embeds.** `/api/v1/models.json`, a badge/widget ("live pricing by tokenprice.fyi"), a published CSV of the full history. Counterintuitive but correct: giving the data away is what makes you canonical — every README, dashboard, and blog post that embeds it is a backlink and a reason the ecosystem standardizes on your numbers. The moat isn't the current prices (those are public); it's being the *normalized, versioned, trusted* source of them. Cheap to build on Rails.
3. **The changelog as a media product.** A "what changed this week in LLM pricing" feed — RSS, email, posted to the site. The market events table is the seed of this. Pricing news is a recurring reason to return that a static table never gives anyone; it converts SEO drive-by traffic into subscribers, and subscribers into the alert audience (section 7).
4. **Decision artifacts, not just data.** The calculator permalinks and task-profile guides from sections 4–5. Tables get checked; artifacts get *shared*. Sharing is the only realistic growth channel for a product like this.

**What I would deliberately not do:** benchmarks (arms race, off-brand), an inference gateway/proxy (that's OpenRouter — your data source and 100x your size), spend-tracking dashboards requiring API-key access (a real but different product — heavy trust ask, crowded space; revisit only after the audience exists). Stay the neutral, trusted *reference and decision layer* — the Kelley Blue Book of LLM pricing, not the dealership.

## 7. Top 3 Product Bets

**Bet 1 — Workload cost calculator with shareable permalinks.** *(Impact: high · Effort: low — ship first.)*
This converts the product's core weakness ($/Mtok ≠ a budget) into its core strength, using only data already in the database. It's a few controllers and views in a stack built for exactly this — no new infrastructure, no new data dependencies. It changes the user's question from "what does a million tokens cost?" (answerable anywhere) to "what does *my workload* cost?" (answerable nowhere else with live, history-backed prices). Shareable URLs make every serious user a distribution channel, and "savings vs. your current model" gives the site its first screenshot-worthy artifact. Every later bet builds on it.

**Bet 2 — Price-change alerts + public changelog/RSS.** *(Impact: high · Effort: medium.)*
The product's most valuable event — a price change — currently notifies nobody. A "watch this model / watch the market" email (plus RSS and a public changelog page) is the retention engine: it turns anonymous SEO traffic into the product's first owned audience, and it's the foundation for everything monetizable later (team alerts, API tiers). The sync job already detects exactly the trigger moment (it appends a `PricePoint` only when price actually moved), so the hard part is solved; what's left is email delivery and a subscription record — well within a weekend-scale Rails effort. This is also the bet that most directly compounds the historical-record moat: the changelog *is* the history, productized.

**Bet 3 — Task-profile model picker ("cheapest model that's good enough").** *(Impact: highest long-term · Effort: high — start small.)*
This is the bet that moves the product from reference to advisor, and it's where the durable brand lives — nobody neutral and trusted currently answers "which tier do I actually need for X?" It's ranked third only because it requires sustained editorial investment: the token-shape math is easy, but the tier-fit judgments must be maintained as models improve, and credibility dies fast if guidance goes stale. Start with 5 profiles, date-stamp every judgment, wire each profile into the calculator as a preset, and let SEO performance ("best cheap model for classification") tell you which profiles to deepen. If this works, it becomes the front door of the product and the calculator becomes its checkout.

*(Honorable mention, do alongside rather than instead: the free JSON API — near-zero effort, pure compounding distribution.)*

## 8. Positioning Statement

> **tokenprice.fyi is the live price index for LLM APIs — every model, every provider, normalized, sourced, and tracked over time. Estimate what your workload will actually cost, find the cheapest model that's good enough, and get told the moment the market moves.**

---

### Bottom line

As it stands, this is an excellently engineered commodity: the table is replaceable, but the append-only sourced price history and the curation discipline are not — they're the foundation of a record-of-record nobody else is building. The product becomes indispensable the day it stops answering "what does a million tokens cost?" and starts answering "what will *my thing* cost, on which model, and when did that answer change?" The calculator gets it there fastest, alerts make it sticky, and task guidance makes it the authority. Ship them in that order.
