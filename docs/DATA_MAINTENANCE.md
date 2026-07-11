# Data maintenance & backfill — curated pricing categories

How the hand-curated pricing categories stay accurate, and how to push updates
to production. Read this before re-verifying prices or backfilling prod.

## What's curated vs. synced

- **Synced (self-maintaining):** the **language** models sourced from OpenRouter
  (`source: "openrouter"`). A daily job refreshes their per-token prices — you
  don't touch these.
- **Curated (hand-maintained):** everything with `source: "manual"` — the five
  directory categories (**image generation, embeddings, speech-to-text,
  text-to-speech, video generation**) plus any hand-entered language rows. No job
  refreshes these; their figures drift as providers reprice, so they need a
  periodic human pass. That's what this doc is about.

## Source of truth: two files move together

For each curated category, a price lives in two places that must stay in sync:

| File | Role |
|---|---|
| `docs/<CATEGORY>_MODEL_PRICING.md` | The **sourced dataset** — every figure with its source URL, confidence (H/M/L), and as-of date. The authority for *what's true*. |
| `db/seeds.rb` | The **seed rows** loaded into the DB. Idempotent (`find_or_initialize_by` on slug). The authority for *what ships*. |

Changing a price = update the pricing doc **and** the seed row
(`native_price_usd` / `price_summary` + `priced_as_of`), then reseed. Never edit a
price in one without the other.

The pricing docs: `IMAGE_MODEL_PRICING.md`, `EMBEDDING_MODEL_PRICING.md`,
`SPEECH_TO_TEXT_MODEL_PRICING.md`, `TEXT_TO_SPEECH_MODEL_PRICING.md`,
`VIDEO_MODEL_PRICING.md`.

## Backfilling production

Deploys run `db:prepare` (create + migrate) automatically but **not** `db:seed`.
So new curated models — a freshly launched category's roster, or a re-verified
price — reach production only when you run the seed:

```
bin/kamal seed          # alias for: app exec --reuse "bin/rails db:seed"
```

- **Idempotent** — safe to run repeatedly. It upserts curated rows by slug,
  updates prices and `priced_as_of`, and prunes price snapshots no longer listed.
- **Non-destructive to synced rows** — seeds only define `source: "manual"` rows;
  the OpenRouter-synced language rows are untouched.
- **After each category-tab deploy**, run `bin/kamal seed` once to light up the
  new tab with its data. (That's the backfill step for the speech-to-text,
  text-to-speech, and video tabs shipped recently.)

## Ongoing maintenance: the staleness report

`pricing:staleness` lists every curated price by category with its age, flagging
what to look at:

```
bin/rails pricing:staleness           # locally
bin/kamal staleness                   # against production
DAYS=180 bin/rails pricing:staleness  # change the threshold (default 90)
```

Each row is marked:

- **⚠ stale** — priced more than `DAYS` ago (default 90). Re-verify.
- **? undated** — has a native price but no `priced_as_of`, so its age can't be
  known. Add a date.
- **· unpriced** — a directory row listed but awaiting any price (a model whose
  provider publishes no usable rate yet, e.g. Luma Ray3.14). Fill in when a rate
  appears, or leave it honestly "not yet tracked".

**Suggested cadence: quarterly.** Provider prices move a few times a year; a
90-day threshold catches drift without busy-work.

## The re-verify loop (per flagged row)

1. Open the row's entry in `docs/<CATEGORY>_MODEL_PRICING.md`; re-fetch the
   provider's official pricing page.
2. **If the price changed** — update the figure + as-of date in the pricing doc,
   then update `native_price_usd` / `price_summary` **and** `priced_as_of` in
   `db/seeds.rb`.
3. **If unchanged** — bump `priced_as_of` to today in both the doc and the seed
   (the price is still current; this clears the stale flag).
4. `bin/rails db:seed` locally → `bin/rails test` → commit → deploy → `bin/kamal
   seed`.

## Adding a new category

The pattern is documented in the per-category plans (`docs/*_TAB_PLAN.md`,
`docs/*_CATEGORY_PLAN.md`): a `ModalityClass` rule, a `ModelCategory` registry
entry, a route, a sourced `docs/<CATEGORY>_MODEL_PRICING.md`, and seeds. The
controller, view, and sitemap are registry-driven, so they need no edit. After it
ships, `bin/kamal seed` backfills the roster — same as any other curated update.
