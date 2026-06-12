# Next steps — owner checklist (June 2026)

Written for future-you, assuming you've lost the context. Work top to bottom;
Part A is urgent, Parts B–C are when you have an hour.

## What happened (30-second recap)

The site now has 2–3 years of historical pricing data (81 models, 99 price
points, back to GPT-4 in March 2023), all merged into `main`. The pieces:

| File | Role |
|---|---|
| `db/seeds.rb` | **The canonical record.** Every model and dated price point, hand-edited, idempotent (`bin/rails db:seed` re-runs safely). |
| `docs/SEED_PRICE_VERIFICATION.md` | Checklist of Wayback Machine captures to verify each seeded price against. Your main task is here. |
| `docs/backfill/litellm_price_changes.md` | Output of the LiteLLM history miner (`rake backfill:litellm_history`): every price change the community dataset recorded, with hand-curated verdicts. Discovery only — never seeded directly. |
| `app/controllers/sources_controller.rb` → `/sources` | Public attribution page, built live from the `source` field on every price point. |

Everything below was seeded with at least secondary-source confirmation;
your job is the final first-party verification that only a human with a
browser can do (the Wayback Machine is blocked from Claude Code sessions).

---

## Part A — Security (do first, ~15 minutes)

A Docker Hub access token was accidentally committed to `main` in
`.kamal/secrets.local` on 2026-06-12. The git history has been rewritten and
force-pushed to remove it, but the token was exposed on GitHub and must be
treated as compromised.

1. **Rotate the Docker Hub token** (if you haven't already):
   - hub.docker.com → Account Settings → Personal access tokens.
   - Revoke the old token (created ~June 2026, used by Kamal for registry
     push/pull), create a replacement.
   - Put the new value in `.kamal/secrets.local` on your machine. The file is
     now gitignored **and** untracked, so it stays local. Never commit it.
   - Confirm deploys still work: `kamal registry login` (or just your next
     `kamal deploy`).

2. **Reset every other clone of this repo** (laptop, server, anywhere):

   ```sh
   git fetch origin
   git checkout main
   git reset --hard origin/main
   ```

   ⚠️ Do this **before** running `git pull` on a stale clone. Because history
   was rewritten, a plain `pull` would merge the old history back in and
   re-publish the secret commits.

3. **Optional:** ask GitHub Support to purge unreachable objects for the repo,
   so the old (pre-rewrite) commits stop being fetchable by SHA.

---

## Part B — Verify the historical data (~1–2 hours, needs a browser)

### How verification works

Open `docs/SEED_PRICE_VERIFICATION.md` and work through the checkboxes. For
each one:

1. Open the Wayback URL. The `web/YYYYMMDD/` form redirects to the nearest
   capture — confirm the date in the Wayback toolbar is **on or after** the
   seed's `effective_on` (and before the next price change).
2. Compare input / output / cached prices per **1M tokens**, standard API tier.
   Watch the traps the doc flags: 2023 pages quote per-1K (×1,000) or
   per-character; Google has context tiers (read the ≤200K column); EUR vs USD
   on early Mistral pages.
3. Match → tick the box. Mismatch → record it in the **Findings** table at the
   bottom of the doc, then fix the seed (rules below).

### What to check, in priority order

**1. Two known discrepancies (most likely to need a fix):**

- **Gemini cached prices may be dated too early.** The seed records Gemini 2.5
  Pro cached at $0.125 and 2.5 Flash at $0.03 from launch (2025-06-17), but
  LiteLLM's history shows those values arriving only in late 2025 / Jan 2026
  (earlier: $0.3125 / $0.075). Check a ~July 2025 capture of
  `ai.google.dev/gemini-api/docs/pricing`. If the higher values were live at
  launch, correct the seed's cached figures and add later points for the cuts.
- **Kimi K2.5 / K2.6 output rates.** Seed says $2.50 out for both; LiteLLM
  (from Moonshot's own docs) says $3.00 (K2.5) and $4.00 (K2.6). Check
  `platform.moonshot.ai` captures — whichever is the *direct API* rate wins.

**2. Three approximate dates to pin (values are confirmed, dates are not):**

- o1-mini's cut to $1.10/$4.40 — seeded as 2025-01-31 (the o3-mini launch).
- Grok 2's API beta at $5/$15 — seeded as 2024-10-21 (xAI API public beta).
- Claude Instant's reprice to $0.80/$2.40 — seeded as 2023-11-21 (alongside
  Claude 2.1; HN only noticed it 2023-12-13).

Each has a "date approximate — confirm via Wayback" note in `db/seeds.rb`.
Once pinned, correct `on:` if needed and replace the note with e.g.
`"confirmed via Wayback capture 2025-02-08"`.

**3. Two unseeded candidates (add them only if a capture confirms):**

- **Mistral Large v1: $8/$24 → $4/$12 around late May 2024.** LiteLLM saw it
  in the 2024-05-23 → 05-31 window; no first-party announcement found. Check
  `mistral.ai/technology/#pricing` captures from early June 2024. If real,
  append to the `mistral-large` `prices` array.
- **DeepSeek V3 launch promo: $0.14/$0.28 from 2024-12-26 to 2025-02-08.**
  The seed deliberately starts at the post-promo $0.27/$1.10. Optional — add a
  launch point if you want the chart to show the price that shocked the
  market in Dec 2024.

Whatever you decide, update their verdicts in
`docs/backfill/litellm_price_changes.md` (the curated section at the top) so
the audit trail stays honest.

**4. The rest of Pass A and Pass B** in the checklist — box-ticking
confirmation of figures that searches already corroborated. Do it before
publicly calling the dataset verified; nothing there is flagged as doubtful.

### How to apply a fix to the seed

All edits go in `db/seeds.rb` (never directly in the DB):

- **Wrong value** → correct the figures on the existing price point.
- **Wrong effective date** → correct that point's `on:`. Re-seeding prunes the
  old-dated row automatically.
- **Missed change** → append `{ on: "...", in: X, out: Y, src: "...", note: "..." }`
  to that model's `prices` array. Keep the old point — that's what draws the
  step on the chart.

Then:

```sh
bin/rails db:seed     # idempotent; updates in place
bin/rails test        # should stay green: ~128 runs, 0 failures
```

Log every change as a row in the Findings table, commit, push to `main`.

---

## Part C — Deploy (~5 minutes)

Production needs the new seed data once (afterwards the daily OpenRouter sync
keeps current prices fresh on its own):

```sh
kamal app exec "bin/rails db:seed"
```

Then sanity-check on the live site: a model page with multi-point history
(e.g. GPT-3.5 Turbo or Claude 3.5 Haiku should show a price-cut step), the
Trends chart reaching back to 2023, and the new `/sources` page rendering
its attribution tables.

---

## Re-running the miner later (optional, occasional)

To check whether LiteLLM's history has recorded anything new since June 2026:

```sh
git clone --filter=blob:none --no-checkout https://github.com/BerriAI/litellm /tmp/litellm-probe
bin/rails backfill:litellm_history
git diff docs/backfill/litellm_price_changes.md
```

New rows in the change log = candidates to verify and fold in, same loop as
above. The hand-curated verdicts section at the top of the artifact survives
reruns. Remember it's discovery, not truth: a LiteLLM commit proves a price
changed *by* that week, not *on* it.
