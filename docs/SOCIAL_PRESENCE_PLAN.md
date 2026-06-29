# Social presence plan — automated BlueSky & Mastodon (June 2026)

Written for a future agent (or future-you) picking this up cold. Goal: stand up
an automated social presence on BlueSky and Mastodon that posts the pricing
events this app already detects, and use it to reinforce the one thing nobody
else has — **verified price history**. This is a sibling to `docs/GROWTH_PLAN.md`
(it expands Tier 3, "Distribution") and shares its guardrails and copy rules.

## 30-second situation

The app already produces everything a pricing account needs to post — it just
goes to Slack and an admin review queue instead of out to the world. Every day:

- `OpenRouterSyncJob` (6am) detects **price moves** and **new model launches**
  and hands `OpenRouter::SyncDigest` the structured records
  (`RepricedRecord`, `CreatedRecord`).
- `NewsScanJob` (5am) + `ReleaseWatchJob` (every 6h) ingest and classify
  **pricing news** into `NewsItem`s (`kind`: release/price/market/other, plus a
  one-sentence `rationale`).
- `EventCurationJob` (7am) turns the best of that news into **draft
  `MarketEvent`s** that a human reviews and publishes — each with a `title`,
  `note`, and `source_url`.

So automated posting is mostly a new **transport**, not new content. The content
exists; it's structured; it's idempotency-stamped (`notified_at`). We add two
thin clients, a formatter, and a few job hooks.

### The wedge (don't lose it)

`GROWTH_PLAN.md` is emphatic: we don't win as "another price calculator," we win
on **price history with receipts**. Every post must reinforce movement over time
("output dropped 33% today", "unchanged since launch 14 months ago"), not just a
snapshot anyone could quote. The destination link should be **our** model/event
page (with the original article credited as a source), not a bare relink that
sends traffic away and is undifferentiated.

### What we are NOT doing

- Not relinking the raw `NewsItem` firehose headline-by-headline
  (`NewsDigestJob` batches up to 48/day to Slack — that volume on social reads as
  spam, and unreviewed Haiku classifications occasionally surface junk under our
  name). The good news already flows through human review into `MarketEvent`s;
  post *those*. A filtered weekly news roundup is a deferred, optional add (P4).
- Not posting to external platforms before the owner has approved the account,
  the handles, and a sample of real drafts (see Guardrails).

---

## Architecture fit

The codebase makes this clean — there's an established pattern for every piece.

- **Transport mirrors `lib/slack_notifier.rb`.** Two new thin `lib/` clients,
  `Net::HTTP` direct (no new gem), each reading its secret from Rails encrypted
  credentials and **no-opping when the credential is blank** — so dev, test, and
  CI stay silent automatically, exactly like Slack does today.
  - BlueSky: AT Protocol. Create a session
    (`com.atproto.server.createSession` with handle + app password) to get an
    access JWT, then `com.atproto.repo.createRecord` with an
    `app.bsky.feed.post`. Link previews need a separately-uploaded `external`
    embed (`com.atproto.repo.uploadBlob` + an `app.bsky.embed.external` facet);
    start without it, add later.
  - Mastodon: one call — `POST /api/v1/statuses` with a bearer access token and
    `{ status: "…" }`. Link card is generated server-side by the instance.
- **The message is domain presentation, not transport.** Formatting a post is the
  same shape as `OpenRouter::SyncDigest` (which already turns a sync `Result`
  into a Slack payload). Keep `lib/` dumb: a `SocialPost` value object (or
  `to_bluesky` / `to_mastodon` methods on the existing digest objects) owns the
  copy and the character budget; the clients just send a string.
- **Jobs stay thin wrappers.** `OpenRouterSyncJob` already runs daily and calls
  Slack; it gains a sibling call to the social transport. New cadences are new
  thin `config/recurring.yml` entries (Solid Queue, production only).
- **Idempotency reuses the `notified_at` idea.** `NewsItem` already stamps Slack
  posting to avoid re-notifying; add the equivalent per-surface stamp so a move
  or event is never double-posted (see P1 for the column choice).
- **Secrets follow `CLAUDE.md`.** Handles and tokens are runtime secrets →
  Rails encrypted credentials (`bin/rails credentials:edit`), read via
  `Rails.application.credentials.…`. Nothing goes in `config/deploy.yml` env.

Proposed credential keys (nested):

```yaml
bluesky:
  handle: tokenprice.fyi          # or the bsky.social handle
  app_password: xxxx-xxxx-xxxx-xxxx
mastodon:
  instance_url: https://mastodon.social
  access_token: xxxxxxxx
```

---

## P1 — Transports + post published market events (the first slice)

**Why.** Published `MarketEvent`s are the highest-quality automated content we
have: already filtered from news, rewritten in our voice (`title` + `note`),
human-approved, and carrying a `source_url`. Wiring the transport to the publish
action is the smallest change that puts real, differentiated pricing news out
automatically — and it doubles as the end-to-end test of the two clients.

**Files.**
- New `lib/bluesky_client.rb`, `lib/mastodon_client.rb` — model on
  `lib/slack_notifier.rb` (credential read, https-only, blank → no-op, raise on
  non-success).
- New `app/models/market_event/announcement.rb` (or a `to_social` method on
  `MarketEvent`) — builds the post string from `title` / `note` / event URL,
  within each platform's limit (BlueSky 300 graphemes, Mastodon 500).
- `app/controllers/admin/market_events_controller.rb` — the `publish` action
  (lines 45–48) is the hook. Prefer firing from a model callback or a
  `market_event.announce` method over inlining HTTP in the controller (controllers
  stay thin; see `CLAUDE.md`).
- DB: add `announced_at` (datetime, nullable) to `market_events` so a re-publish
  or a backfill never double-posts. Guard the post on `announced_at IS NULL`.
- Credentials (above).

**Steps.**
1. Build the two clients; unit-test the no-op-when-blank path (mirrors the Slack
   test) and stub HTTP for the success/failure paths.
2. Build the announcement formatter. Voice = `CLAUDE.md` copy rules: specific
   numbers, no marketing, link to the event/model page, credit `source_url` if
   present. Example:
   > Anthropic cut Claude Sonnet output pricing: $15 → $10 per 1M tokens.
   > History since launch → tokenprice.fyi/models/claude-sonnet-4-6
3. Hook `publish`: on success, post to both platforms, stamp `announced_at`. Make
   posting failures non-fatal to the publish (log + Honeybadger, don't 500 the
   admin action) — the event should publish even if BlueSky is down.
4. Decide the destination URL: model page when the event maps to one model,
   else the `/events` timeline anchor.

**Done when.** Publishing a market event in admin posts a correctly-formatted
status to both BlueSky and Mastodon (verified against real test accounts),
stamps `announced_at`, never double-posts, and a blank credential makes the whole
path a silent no-op (CI green with no secrets).

---

## P2 — Auto-post price moves and new launches from the daily sync

**Why.** Price moves are the flagship wedge content — only we can post "X dropped
33% today, here's the history." `OpenRouter::SyncDigest` already assembles the
exact records (`RepricedRecord` with old→new input/output and % change;
`CreatedRecord` with launch price), so this is formatting + a job hook, not new
detection.

**Files.**
- `app/models/open_router/sync_digest.rb` — add `to_bluesky` / `to_mastodon` (or
  a `social_posts` method returning per-event strings). Reuse the same
  per-record data it already formats for Slack.
- `app/jobs/open_router_sync_job.rb` — after the existing Slack call, post the
  social variants.
- Idempotency: the sync is append-only and runs once daily, so a per-run guard is
  usually enough; if finer control is wanted, stamp the `PricePoint` /`AiModel`
  (e.g. `announced_at` on the price point) rather than re-deriving "is this new".

**Steps.**
1. **Set a noise threshold.** A busy sync day can reprice many models; posting
   each is chatty. Options (pick one, make it config): post only moves ≥ N%
   absolute change; always post launches; roll the rest into the weekly digest
   (P3). Recommend: launches always, moves ≥ ~5%, remainder → weekly.
2. Format per-event in voice, one post per significant event, each linking the
   model page. Use `AiModel#latest_price_move` / `price_change_over` for the
   delta phrasing.
3. `log()` what was filtered out so a quiet day isn't mistaken for a broken job.

**Done when.** A real sync that includes a launch and a ≥-threshold reprice
produces one well-formed post per event on both platforms, sub-threshold moves
are suppressed (and logged), and nothing double-posts across consecutive runs.

---

## P3 — Weekly "biggest movers" digest

**Why.** A low-frequency roundup is more shareable than per-move posts, keeps the
account active in slow weeks, and reinforces "we track everything." It's also the
home for the sub-threshold moves P2 suppresses.

**Files.**
- New `app/models/price_digest.rb` (weekly read-model over `PricePoint` history —
  biggest % movers in the last 7 days, count of changes, cheapest frontier model
  now). A thread on BlueSky / a single longer status on Mastodon.
- New thin job + `config/recurring.yml` entry (e.g. `every monday at 9am`).

**Done when.** A weekly post lists the week's biggest movers with real figures and
links, runs on schedule, and no-ops cleanly on a week with no changes.

---

## P4 — Deferred / optional extensions

- **"On this day" history posts.** Pure wedge content, infinite supply, near-zero
  cost: *"One year ago today, GPT-5 launched at $X/M. Today: $Y/M (−Z%)."* Reads
  straight off dated `PricePoint` history. A daily thin job; skip days with no
  anniversary worth posting.
- **Filtered weekly news roundup (Tier B).** A digest built only from
  `NewsItem.where(kind: "price")` (never raw `other`/`market`), as a roundup —
  not headline-by-headline. Lower priority than our own-data posts; only if the
  cadence needs filling.
- **State-of-pricing report announcements.** When `GROWTH_PLAN.md` T2.2 ships,
  auto-post the headline finding + chart link.
- **Per-post link cards.** Depends on `GROWTH_PLAN.md` T1.4 (per-model OG
  images): once those exist, every auto-post gets a rich price-card preview.
  BlueSky needs the explicit `external` embed (see Architecture); Mastodon picks
  up OG tags automatically.
- **Cross-post to X / LinkedIn.** Reserve the handles now even if we don't post
  there yet; once the formatter exists, adding a transport is cheap.

---

## Suggested order of execution

| # | Task | Effort | Payoff |
|---|------|--------|--------|
| 1 | P1 transports + publish market events | Med | End-to-end posting on our best content |
| 2 | P2 price moves + launches from sync | Med | Flagship wedge content, automated |
| 3 | P3 weekly biggest-movers digest | Low | Cadence + home for small moves |
| 4 | P4 on-this-day / news roundup / cards | Low–Med | Fill, polish, reach |

Highest single leverage: **P2 price moves** (the content nobody else can post).
Cheapest path to a working pipeline: **P1** (one human-gated trigger, both
clients exercised end to end).

## Guardrails

- **Owner sign-off before going live.** Don't create accounts or post publicly
  until the owner approves handles and has seen a batch of real drafts. Until
  then, the blank-credential no-op keeps everything dark by default — the same
  posture as `GROWTH_PLAN.md` ("don't post to external platforms without the
  owner's go-ahead").
- **Voice = `CLAUDE.md` copy rules.** Plain declaratives, specific numbers, no
  marketing constructions, no "Your X is Y." A good pricing post is a fact with a
  link. Minimal hashtags (a couple on Mastodon for discovery; none on BlueSky).
- **Reinforce the wedge.** Link our page; cite the source. Never a bare relink.
- **Posting failures must not break ingestion or admin actions.** Log to
  Honeybadger and continue — a down social API can't take out the daily sync or
  the publish flow.
- **No silent volume.** Any threshold/suppression must `log()` what it dropped so
  a quiet feed isn't mistaken for a broken job.
- **Secrets per `CLAUDE.md`.** Handles/tokens → Rails credentials, never
  `config/deploy.yml`. Tests stub credentials (`stub_anthropic_key!` pattern).
- Run `bin/rails test` before pushing.
