# Historical backfill — 2–3 years of pricing history

*Exploration, June 2026. Goal: make the price history authoritative back to
mid-2023, so the trends page tells the full story of LLM pricing — not just
the models that happen to still be on sale.*

## Where we are today

The seed already reaches back to GPT-4 (March 2023), so the problem is not
range — it's **density and survivorship**:

- ~56 models carry ~64 price points, but only six models have more than one
  point. Most history is a single launch price.
- The market-events table references stories the price charts can't draw:
  the GPT-3.5 Turbo cuts, DeepSeek-V2 igniting China's price war, Mixtral —
  none of those models are in the catalog.
- Several historically important models are missing outright (list below),
  and Pass B of `SEED_PRICE_VERIFICATION.md` already suspects missed
  mid-life price changes for the models we *do* have.

Authority for a "2–3 year record" mostly means adding the dead models and
the in-between price changes. The schema needs nothing new to hold this:
`price_points` already has `effective_on`, `source`, and `note`, and the
unique `[model, effective_on]` index plus the idempotent seed make
backfilling safe to iterate on.

## Data sources, ranked

### 1. LiteLLM's pricing file via git history (discovery goldmine)

[`BerriAI/litellm`](https://github.com/BerriAI/litellm) maintains
`model_prices_and_context_window.json` — community-updated prices for every
major model. Because it lives in git, **its history is a dated record of
every price change since September 2023**.

Feasibility was probed from this environment (June 2026):

- A blob-less clone (`git clone --filter=blob:none --no-checkout`) is cheap.
- 1,591 commits touch the file, 2023-09-06 → 2026-06-10 (updated within a
  day of Claude Fable 5 shipping).
- Demonstration: the `o3` entry reads $10/$40 per MTok at the 2025-06-06
  commit and $2/$8 by 2025-06-12 — correctly bracketing the known
  2025-06-10 cut.

**Caveats:** commit dates lag real effective dates by 0–14 days; entries are
occasionally wrong or use dated snapshot IDs (`claude-3-5-sonnet-20240620`)
that need mapping to our marketing-name slugs; costs are USD *per token*
(multiply by 1e6). Treat this source as **discovery, not truth**: it finds
the changes and approximate dates; first-party pages confirm them.

### 2. Wayback Machine (verification + exact dates)

Already our documented process (`SEED_PRICE_VERIFICATION.md`). Two upgrades
for backfill use:

- The CDX API (`web.archive.org/cdx/search/cdx?url=…`) lists every capture
  of a pricing page programmatically — no manual calendar clicking.
- Binary-searching captures around a LiteLLM-discovered change narrows the
  effective date to a day or two.

Note: `web.archive.org` is **blocked by the current Claude Code environment
network policy** (github.com is allowed). Either allowlist it in the
environment config or run verification locally.

### 3. Cross-checks and date sources

- **simonw/llm-prices** — small curated repo, also git-history-mineable;
  good second opinion.
- **First-party announcements** (OpenAI/Anthropic/Google/DeepSeek blogs and
  changelogs) — the authoritative *effective dates*; the seed already cites
  press coverage (SCMP, Engadget) where first-party dating is weak.
- **OpenRouter** — current prices only, no public history API; it covers
  the future via the existing daily sync, not the past.

## Recommended approach (three phases)

### Phase 1 — hand-curate the missing backbone (~1–2 days, biggest win)

Add the 2023–2024 models that anchor the story. Candidates, with
best-effort figures to be verified through the existing checklist process
(all USD per MTok, standard tier):

| Model | Why it matters | Price points to verify |
|---|---|---|
| GPT-3.5 Turbo | *The* price-decline story; 4 dated cuts | 2023-03 $2/$2 → 2023-06 $1.50/$2 → 2023-11 $1/$2 → 2024-01-25 $0.50/$1.50 |
| Claude 2 / 2.1 | Pre-Claude-3 Anthropic baseline | 2023-07-11 $11.02/$32.68 → 2.1 2023-11-21 $8/$24 |
| Claude Instant 1.2 | The original cheap tier | 2023-08 $1.63/$5.51 → 2023-11 $0.80/$2.40 |
| Claude 3.7 Sonnet | Fills the Feb–May 2025 Sonnet gap | 2025-02-24 $3/$15 |
| DeepSeek V2 | Triggered China's May 2024 price war (event exists, model doesn't) | 2024-05-06 ~$0.14/$0.28 |
| Mixtral 8x7B + Mistral 7B | The open-weight price floor of the events table | 2023-12 ~$0.70/$0.70 and ~$0.25/$0.25 |
| Grok 3 | xAI gap between Grok 2 and Grok 4 | 2025-04 $3/$15 |
| o3-pro | Premium-reasoning data point | 2025-06-10 $20/$80 |
| Cohere Command R / R+ | New provider; two documented cuts | R+ 2024-04 $3/$15 → 2024-08 $2.50/$10 |
| Llama 3.3 70B | Open-weight 2024 reference rate | 2024-12-06 representative hosted rate |

Also re-verify suspected wrong launch prices while in there — e.g. Mistral
Large 2 may have launched at $3/$9 (July 2024) before a September 2024 cut
to the $2/$6 the seed records as the launch price.

### Phase 2 — mine LiteLLM history for missed changes (~1 day script + review)

A one-off script (a rake task or `script/` file, in the spirit of
`openrouter.rake`):

1. Blob-less clone of LiteLLM; walk commits touching the pricing file in
   date order (sampling weekly is plenty — prices don't flap).
2. Parse the JSON at each step for an explicit **mapping table** of LiteLLM
   model IDs → our slugs (manual, ~60 entries; unmapped IDs are ignored, so
   the firehose of models we don't track stays out).
3. Emit a change log: `slug, commit_date, old in/out/cached, new in/out/cached`.
4. Human reviews the diff list, confirms each change against Wayback or an
   announcement, and folds it into `db/seeds.rb` with the first-party
   `src:` and a `note:` (`"date via litellm history, confirmed on …"`).

The output is **a review artifact, not a DB import** — `seeds.rb` stays the
single hand-audited record, which is what makes the dataset citable.

### Phase 3 — surface the provenance (small, makes the authority visible)

- Run the full `SEED_PRICE_VERIFICATION.md` pass over old and new points;
  extend the checklist with the new snapshots.
- Optional schema niceties (each a one-line migration): `source_url` on
  `price_points` (full link, including the Wayback capture used),
  `verified_on` date (the product vision's "last verified" stamp), and a
  `date_approximate` flag for points only dateable to a week.
- The changelog page from the product vision then falls out of the data:
  "every LLM price change since 2023, dated and sourced."

## Pitfalls to respect

- **Effective dates vs. discovery dates.** A LiteLLM commit proves the
  price changed *by* that date, not *on* it. Never seed a commit date
  unverified; use the existing `note:` convention for approximations.
- **Model identity policy.** We chart marketing lines (one "GPT-4o" with
  two points), even where the provider shipped the cut as a new dated
  snapshot. Keep that policy, but write it down in the seed header so
  backfill contributors don't split models.
- **Unit traps.** Pre-2024 pages quote per-1K tokens; Gemini has context
  tiers; cache *read* vs *write* differ. Normalize to the same convention
  the seed already uses (per-MTok, standard tier, ≤200K tier for Google,
  cache read).
- **Open-weight rates.** Hosted Llama/Mixtral prices vary by provider —
  keep the "representative rate, ±20%" policy from the verification doc.
- **Survivorship is the point.** Retired models (status `retired`) are
  what make the 2023–2024 chart honest; don't skip a model because it's
  dead.

## Effort summary

| Phase | Effort | Outcome |
|---|---|---|
| 1. Backbone models | 1–2 days curation | Every quarter since early 2023 has chartable data |
| 2. LiteLLM mining | ~1 day script + review session | Missed mid-life changes recovered with dates |
| 3. Verification + provenance | Checklist pass + tiny migrations | The record becomes auditable, hence citable |
