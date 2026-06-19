# Quality ratings — should the index show how good a model is? (June 2026)

A recurring idea: alongside price, show some signal of model **quality** —
benchmark scores, a leaderboard rank, an Elo, a star rating. This memo
records the decision and the reasoning so it doesn't get re-litigated every
few months.

## Short answer

**No scoreboard. No stored quality number that's ours.** Keep cost as the one
axis we're authoritative on, keep `tier` as the quality *floor*, and **link
out** to the leaderboards for anyone who wants a capability ranking. The only
quality signal we author is the dated, hedged editorial sentence we already
write (`strengths` / `best_for` / `limitations`) — a judgment, never a score.

This isn't a new call. It's already written into the vision; this memo just
makes the trade-offs explicit and turns the link-out into a concrete step.

## Why — the stance is already on the record

From `docs/PRODUCT_VISION.md`:

> We never compete on model **quality**. Benchmarks are an arms race against
> funded leaderboards, they go stale, and they're off-brand for a neutral
> price source. We lead with cost — the one axis we can be authoritative on —
> and treat quality as a tier floor, never a score.

And in the same doc's "What we deliberately don't do":

> **Quality benchmarks** — an arms race; off-brand. Link out instead.

The editorial voice already commits to this in public, on `/which-model`:

> The eval is the arbiter, not this page and not a leaderboard.
> … these are dated judgments, not benchmarks — they say "good enough for
> typical schemas," never "scores 87.2."

Adding a score column would directly contradict copy we've already shipped.

## The options, and why each lands where it does

**A. Import raw benchmark scores** (MMLU, GPQA, SWE-bench, AIME, etc.) — _reject._
- A maintenance treadmill: scores change with every release and every harness
  tweak, and there's a new benchmark every month. That's exactly the
  "build-once-compounds vs. treadmill" line the vision draws — owner attention
  is the scarce resource.
- Goes stale invisibly. A wrong price is embarrassing; a stale benchmark is
  worse because it *looks* authoritative.
- We can't be a source of truth here. We'd be re-publishing someone else's
  numbers, which is the opposite of the sourced, first-party-verified posture
  the price history earns us.

**B. A single aggregate index** (Artificial Analysis "Intelligence Index",
LMArena / Chatbot Arena Elo) — _reject as a stored column; allow as a link._
- Less noisy than raw benchmarks, but it's still someone else's number with
  its own methodology, refresh cadence, and biases (Arena rewards style and
  voter preference; AA weights its own basket). Baking it into our table
  launders their opinion as our data.
- Licensing/attribution overhead for a number we don't control.
- Fine to *point at*. Not fine to *own*.

**C. The `tier` floor** (`frontier` / `mid` / `small`) — _keep; this is the answer._
- It's a coarse capability signal that ages gracefully ("good enough for X"),
  not a precision claim that rots ("87.2"). It already filters the table,
  ranks "cheapest frontier", and structures `/which-model`.
- It's honest about what it is: a re-curatable judgment. OpenRouter imports
  land in a neutral `mid` for a human to re-curate (see README), precisely so
  a bulk import can't fake a quality claim.

**D. Editorial facets** (`strengths` / `best_for` / `limitations`) — _keep._
- These are dated, hedged, plain-language judgments — the on-brand form of
  "quality." They fold into `long_description` and the model page already.
- The rule that keeps them safe: describe fit ("strong at long-context
  extraction"), never assert a rank or a score.

**E. "Price per unit of quality" / cost-per-intelligence** — _tempting, reject building._
- Superficially on-brand (it's cost-led) and it's the one framing worth
  revisiting later. But dividing our authoritative price by a borrowed score
  contaminates the axis we're trying to keep clean: the output is only as
  trustworthy as the denominator, and the denominator is the thing we just
  said we can't stand behind. If we ever show it, it must read as *their*
  sourced number with a date and a link — exactly how a `PricePoint` carries
  its `source` — not as a tokenprice figure.

**F. Link out to the leaderboards** — _recommended, additive, cheap._
- Reinforces neutrality instead of diluting it: "we're authoritative on price;
  for capability, here are the people who do that, and write an eval." That's a
  trust signal, not a gap.

## Recommendation (concrete)

1. **Don't** add a benchmark/score/Elo column to the table, the model page, or
   the API. No new `ai_models` columns for scores.
2. **Keep** `tier` as the quality floor and the editorial facets as the only
   authored quality signal. They already exist and are already on-brand.
3. **Add a small, clearly-attributed "capability / quality" link-out** — a few
   lines on the model page and/or a footer block on `/which-model` — pointing
   to the external rankings (Artificial Analysis, LMArena, the provider's own
   model card) with one sentence: *we track price; for quality, validate with
   your eval or see these.* This is the whole build. It's static, it compounds,
   and it makes the "we don't do scores" stance a feature rather than an
   omission.
4. **Treat any future quality number as external data, not ours** — sourced,
   dated, attributed, and visibly someone else's, the same discipline as a
   price point's `source`.

## What would change this answer

The gate is demand, measured cheaply. If the link-out earns real clicks — i.e.
people clearly want a capability axis next to price — revisit option E (a
cost-per-external-index view), but still as *attributed external data with a
date*, never as a benchmark we run or a score we mint. The line that doesn't
move: tokenprice is authoritative on cost; on quality it points, it doesn't
score.
