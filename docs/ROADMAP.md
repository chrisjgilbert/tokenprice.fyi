# Roadmap — July 2026

A pin in the product. Full rationale, findings, and the pressure test behind
every line here live in `docs/PRODUCT_ANGLE_REVIEW.md`.

**What this is:** the price record of AI model APIs — every price dated,
sourced, and watched for changes. Full from-launch history for language
models; history for the other categories begins when tracking begins.

**Goals it serves:** a product to be proud of, some traffic, low
maintenance. Not category-winning.

The split below is fix vs. enhance: the short-term goal was that the product
*hangs together* — copy and journeys all make sense — and everything
additive waits behind that. **Section 1 (the fixes) shipped and merged in
#144 (July 2026); sections 2 and 3 are what remains.**

## 1. Hang together — DONE (shipped in #144, July 2026)

All of the "fixes" phase landed on `main`. Kept here as the record of what
changed:

**Copy now says what the product is** — category-aware hero (per-tab
eyebrow / heading / subhead from `ModelCategory`, filled with the tab's own
model count); record-framed default `<title>`/meta/OG and Organization
JSON-LD; footer off the site-wide "per 1M tokens" claim; category-neutral
/compare, /events, /changes titles; llms.txt lists all seven category URLs
and states the two tiers; PWA manifest, README, and the learn index lede
updated.

**Journeys hang together** — model breadcrumb returns to the model's own
category tab; provider pages group by category via a shared
`models/_data_cell` partial (no more blank per-token cells); /compare is
scoped to one category with per-category row shapes; `/events` launches show
native price headlines; the untracked-price fallback reads the category's
billing unit; model JSON-LD uses the modality label; `priced_as_of` shows on
the directory tables; tab switches preserve scroll.

**The data layer stopped contradicting itself** — the commodity public JSON
API was removed (`PriceCatalog` stays an internal seam; see the
`PRODUCT_VISION.md` July update); native price changes now append a dated
`NativePriceSnapshot` (history begins when tracking begins); a weekly
`PricingStalenessDigestJob` posts flagged stale/undated/unpriced counts to
Slack.

One knock-on for the sections below: append-only snapshots plus the weekly
staleness ping make the section-2 re-verification *guided* — you're told
which rows are due and each pass deposits history — rather than a
from-memory chore.

## 2. Grow (next — the current focus)

- **More models.** Language grows semi-automatically (OpenRouter sync +
  candidate queue). Deliberate effort goes to the directory categories via
  the curation queue and seed docs. Re-verification runs as a rotation —
  one category per month (~8–22 rows, an evening; each category refreshed
  roughly twice a year) — instead of the all-at-once October cliff.
- **Education.** In order: the umbrella explainer ("Billing units across AI
  APIs" — the page every category tab can cross-link); regroup the learn
  index into "Per-token pricing" / "Other billing units"; then the
  per-category pieces demand-gated — generation (image/video), then speech
  (STT+TTS), then embeddings if its umbrella section outgrows itself.
  Rerank stays a paragraph in the umbrella. New widget plumbing: a
  min/median/max strip off each category's `price_headline` values.

## 3. Enhance (later — additive, pinned)

- **RSS change feed** off /changes — the shortest path from the record to a
  return-visit habit; preferred over email (no subscriber-support burden).
- **Benchmarks layer** — quality indication next to prices, entering the
  same way prices do: sourced, dated, attributed, never the site's own
  verdict. Researched and feasible (details and licensing table in the
  review doc): start with the Arena leaderboard dataset (CC-BY-4.0, covers
  language/image/video in one ingestion job), MTEB for embeddings, Open ASR
  for STT, Epoch AI for static evals; TTS and rerank honestly show "no
  independent score"; Artificial Analysis only with their permission.
  Ingestion as a scheduled job in the `ModelSync` mould; label Elo,
  static-eval, and usage signals as different kinds of number.

## Standing maintenance budget

Recurring human work stays at: model-candidate review (minutes), market-
event curation (discretionary), one directory category re-verified per
month, a weekly glance at the staleness ping. Out of budget by default:
email products, breadth-chasing, and any new standing content commitment
beyond the education track above.
