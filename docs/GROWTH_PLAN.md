# Growth plan — exposure & traction (June 2026)

Written for a future agent (or future-you) picking this up cold. Goal: get
tokenprice.fyi in front of more people and convert them into returning users.
Work the tiers top to bottom — Tier 1 is cheap and high-leverage, later tiers
compound on it. Each task lists **why**, **files**, **steps**, and **done when**.

## 30-second situation

This is a crowded niche. The category is full of LLM price calculators —
artificialanalysis.ai (~1M visits/mo), pricepertoken.com, llmpricecheck.com,
llm-prices.com, llmgateway.io, BenchLM, 302.ai, and more. As of writing,
tokenprice.fyi has **near-zero search footprint** (the brand name doesn't
surface; `.fyi` SERPs are all crypto).

We don't win by being a better calculator. We win on the **one thing nobody
else has: verified price *history*** (every price change since 2023, with
Wayback receipts — see `docs/SEED_PRICE_VERIFICATION.md`). Everyone shows
today's price. We show how it moved. Every task below should reinforce that
wedge.

Two acquisition surfaces, optimise both:
1. **Search** (Google + answer-engines like ChatGPT/Claude answering "how much
   does X cost") — won by programmatic long-tail pages + structured data.
2. **Being the cited reference** — direct/referral traffic (the way
   artificialanalysis won; ~47% of their traffic is direct) — won by data
   journalism + an embeddable/citable API.

### Current SEO posture (already in place — don't redo)

- Server-rendered ERB, fast, clean slugs (`/models/claude-opus-4-8`,
  `/providers/anthropic`). Good crawlability.
- JSON-LD on homepage (ItemList), model pages (Product + BreadcrumbList), `/why`
  (Article), `/sources` (WebPage). Helper: `app/helpers/application_helper.rb`
  → `json_ld`.
- Canonicals set on index / cost / learn pages; layout falls back to
  `request.original_url`. Layout: `app/views/layouts/application.html.erb`.
- Sitemap at `/sitemap.xml` (`app/views/sitemaps/index.xml.erb`,
  `SitemapsController`) covering 11 pages + all providers + all models.
- `public/robots.txt` allows all, disallows `/admin`, declares the sitemap.
- Cloudflare Web Analytics in the layout. **No Google Search Console / Bing yet.**
- Public read-only JSON API at `/api/v1/models.json` (CORS `*`).

---

## Tier 1 — Fix the SEO foundation (cheap, do first)

### T1.1 — Per-page meta descriptions on model & provider pages

**Why.** Today every model page and provider page inherits the *generic
site-default* `meta description` from the layout. To Google, 40+ pages look
like near-duplicate content, which wastes our single biggest long-tail asset
(model-specific pricing queries). This is the cheapest high-impact fix.

**Files.**
- `app/views/models/show.html.erb` — add `content_for :description`.
- `app/views/providers/show.html.erb` — same.
- Layout already renders `content_for(:description)` with a fallback, so no
  layout change needed. Confirm at `app/views/layouts/application.html.erb`.

**Steps.**
1. Model page: template real numbers, e.g.
   `"#{model.name} (#{provider.name}) API pricing: $#{input}/M input, $#{output}/M output per 1M tokens. Price history since launch, cached & batch rates, and a cost calculator."`
   Keep under ~155 chars; truncate gracefully. Reuse existing price helpers
   (`current_price`, `blended_per_mtok` on `app/models/ai_model.rb`).
2. Provider page: `"All #{provider.name} model prices — #{count} models from $X/M. Compare token costs and see full price history."`
3. While here, set a per-page `content_for :title` if any page is still using
   the default (model/provider/compare titles should be specific).

**Done when.** Every model and provider page emits a unique `<title>` and
`<meta name="description">` containing the model/provider name and at least one
real price figure. Verify with `curl -s https://… | grep -i description` on 3
sample pages.

### T1.2 — Comparison pages (`/compare/:a-vs-:b`) — biggest organic win

**Why.** `"X vs Y"` is the highest-intent, highest-volume query pattern in this
category, and `/compare` is currently a **stub** (`ComparisonsController#show`,
route exists but the view is a placeholder). Competitors rank heavily on these.
We can beat them by adding the history angle ("which got cheaper, and when").

**Files.**
- `config/routes.rb` — add `get "/compare/:pair", to: "comparisons#show"` (keep
  the bare `/compare` as a picker/landing page).
- `app/controllers/comparisons_controller.rb` — parse `:pair` as
  `"<slug-a>-vs-<slug-b>"`, look up both models, 404 cleanly if either is
  missing.
- `app/views/comparisons/show.html.erb` — build the real comparison view.
- `app/views/sitemaps/index.xml.erb` — emit the comparison URLs.

**Steps.**
1. Decide the pair set. Don't generate all N² (thin-content penalty risk).
   Start with: every **cross-provider frontier pair**, plus same-provider
   adjacent-tier pairs (e.g. Opus vs Sonnet). Aim for a few hundred high-value
   pages, not thousands of junk ones. Define the generator in the controller or
   a small service so the sitemap and the picker page share one source of truth.
2. Canonicalise direction: `a-vs-b` and `b-vs-a` should resolve to one canonical
   URL (301 or `<link rel=canonical>`), alphabetical by slug.
3. Page content (must be genuinely useful, not a template shell): side-by-side
   input/output/cached price, blended $/Mtok, context window, the **price-history
   delta** for each ("Opus 4.8 is unchanged since launch; GPT-5.5 doubled in
   Apr 2026"), and a one-line verdict ("cheaper for output-heavy chat: …").
4. Add `Product`/`ItemList` + `BreadcrumbList` JSON-LD, a `content_for :title`
   (`"Claude Opus 4.8 vs GPT-5.5 — price comparison"`) and `:description`.
5. Cross-link: each model page links to its top comparisons; the picker page
   lists them.

**Done when.** Comparison pages render real data both directions, resolve to a
single canonical URL, appear in the sitemap, and link to/from model pages.

### T1.3 — Register Google Search Console + Bing Webmaster Tools

**Why.** We only have Cloudflare analytics, which can't tell us *what queries we
appear for*. GSC is how we'll learn which long-tail terms to double down on.
Bing feeds ChatGPT search. This is a prerequisite for measuring everything else.

**Steps (needs the site owner — agent should produce the artifacts and a
checklist).**
1. Add a verification mechanism. Cleanest for this stack: serve a DNS TXT record
   (owner action) **or** a meta tag. If meta-tag: add an optional
   `content_for :head` hook in the layout, or a config-driven
   `<meta name="google-site-verification">` read from credentials so it isn't
   hard-coded.
2. Submit `https://tokenprice.fyi/sitemap.xml` in both consoles.
3. Document the login/property in `docs/` so it isn't lost.

**Done when.** Both properties verified and sitemap submitted. (Owner step —
agent prepares the verification tag/record and writes the checklist.)

### T1.4 — Per-model Open Graph images

**Why.** One static `public/og.svg` is reused for the whole site, so every
share (Twitter, Slack, Discord, LinkedIn) looks identical and generic. In this
niche links get pasted into a lot of Slacks — a per-model card with the price
and a history sparkline meaningfully lifts click-through.

**Files.**
- `app/views/layouts/application.html.erb` — `og:image` / `twitter:image`
  currently hard-coded to `/og.svg`; switch to `content_for(:og_image)` with the
  static SVG as fallback.
- New: a controller route that renders a per-model OG image. Two options:
  - **SVG (preferred for this stack, no new deps):** a route like
    `/models/:slug/og.svg` rendering an ERB SVG with name, provider, current
    price, and a mini sparkline. Reuse `ChartsHelper` (already renders inline
    SVG server-side). Note: some scrapers don't render SVG OG images well —
    if that bites, rasterise (next option).
  - **PNG:** add an image lib only if SVG proves unreliable; keep the no-Node
    ethos in mind (see `CLAUDE.md`).
- Set `content_for :og_image` on model `show` (and later comparison) pages.

**Done when.** `https://…/models/<slug>` exposes a model-specific `og:image`,
and a link-preview debugger (e.g. opengraph.xyz) shows the price card.

### T1.5 — Sitemap & structured-data quick wins

**Why.** Small crawl-quality and rich-result improvements.

**Files.** `app/views/sitemaps/index.xml.erb`,
`app/views/pages/how_pricing_works.html.erb`, `app/views/learn/*`.

**Steps.**
1. Sitemap `lastmod` for model URLs should be the **most recent price-change
   date**, not `released_on`. Add a helper on `AiModel` (e.g. `last_priced_on`
   = max `effective_on`) and use it.
2. Add comparison URLs (T1.2) and any new pages to the sitemap.
3. Add `FAQPage` JSON-LD to `/learn`, `/how-pricing-works`, `/which-model` (real
   Q&A pulled from the existing copy) so we're eligible for rich snippets and
   AI-overview citations.

**Done when.** Sitemap `lastmod` reflects price changes; learn/explainer pages
emit valid `FAQPage` JSON-LD (validate with Google's Rich Results Test).

---

## Tier 2 — Lean into the history wedge

### T2.1 — Public price-change changelog + RSS feed

**Why.** The release-watcher already polls provider feeds (`config/news_sources.yml`,
the release-watch job) but nothing surfaces publicly. A public "price changes"
feed gives us: fresh-content signals for crawlers, a reason for people to
subscribe and return, automatic things to post, and a genuinely unique artifact
("the LLM price changelog") nobody else has.

**Files.**
- `config/routes.rb` — `get "/changes", to: "changes#index"` and
  `get "/changes.rss"` (or `.atom`).
- New `ChangesController` + views (HTML + RSS builder). The `rss` gem is already
  a dependency.
- Data source: derive from `PricePoint` history — each new point vs. the prior
  one for that model is a "change" event (price up/down/new model/retired).
- Add `/changes` to the sitemap and link it in the nav/footer.

**Steps.**
1. Build a query that yields chronological change events (model, old → new
   input/output, % delta, effective date, source URL).
2. HTML view: reverse-chronological list, grouped by month, each entry links to
   the model page. Match the copy style in `CLAUDE.md` (plain, specific).
3. RSS/Atom feed of the same events; add `<link rel="alternate" type="application/rss+xml">`
   to the layout `<head>`.
4. Optional: a "biggest movers this month" summary block — shareable.

**Done when.** `/changes` lists real price-change events from `PricePoint`
history, a valid RSS feed validates, and both are linked + in the sitemap.

### T2.2 — "State of LLM pricing" report (periodic, data-journalism)

**Why.** This is the backlink/PR play. A quarterly piece off *our* data — who
cut prices, the $/Mtok trend line over time, biggest drops, cheapest frontier
model now vs. a year ago — is exactly the content that hits the HN front page
and earns links. We can produce it because we have history nobody else tracks.
Backlinks are what actually move rankings in a niche this competitive.

**Files.** New `app/views/pages/state_of_pricing.html.erb` (or a dated series,
e.g. `/reports/2026-q2`), route, sitemap entry, charts via `ChartsHelper`.

**Steps.**
1. Pick 4–6 findings the data supports and a human would tweet (e.g. "frontier
   $/Mtok fell N% in 12 months", "the one model that got *more* expensive").
2. Render charts server-side (inline SVG, no CDN — consistent with the stack).
3. Write it in-voice (developer-to-peers, see `CLAUDE.md` copy rules).
4. `Article` JSON-LD with `datePublished`; per-page OG image with the headline
   chart.

**Done when.** A dated report page exists with charts + narrative, is in the
sitemap, and is ready to post (see T3).

---

## Tier 3 — Distribution (get users now)

These are mostly **non-code** — an agent should produce the drafts/assets and
leave the actual posting to the owner (don't post to external platforms without
explicit go-ahead).

> **Automated social presence** (BlueSky + Mastodon) gets its own plan:
> `docs/SOCIAL_PRESENCE_PLAN.md`. It posts published market events and new model
> launches by adding thin `lib/` transports modelled on `SlackNotifier`
> (individual price moves are deliberately kept off the feed as noise). Same
> go-ahead rule applies.

### T3.1 — Show HN, framed on the wedge

Draft a "Show HN" post. **Do not** frame it as "another LLM pricing tool"
(instant downvote). Lead with history + receipts, e.g.
*"Show HN: I tracked every LLM price change since 2023, with Wayback receipts."*
Include: what it is in one line, why you built it, the methodology (`/sources`),
and an invitation for corrections. One shot — pick a US-morning weekday.
Deliverable: `docs/launch/show-hn.md`.

### T3.2 — Reddit, where the question already gets asked

Target subreddits: r/LocalLLaMA, r/LLMDevs, r/ClaudeAI, r/OpenAI, r/SaaS.
Strategy: **answer real "how much does X cost / is Y cheaper" threads** with a
direct link to the relevant model or comparison page — not standalone promo
posts. Deliverable: a short playbook + 2–3 example reply templates in
`docs/launch/reddit.md`.

### T3.3 — Embeddable live price badge (backlink flywheel)

**Why.** Every blog/README that embeds a live price badge is a backlink + brand
impression. The API already exists; make embedding trivial.

**Steps.** Ship a badge endpoint (e.g. `/badge/:slug.svg` →
`Claude Opus · $5/$25`, served from current `PricePoint` data, cache-friendly)
and a copy-paste snippet on each model page ("Embed this price"). Document it
alongside the JSON API. Deliverable: badge route + view + docs; promote the API
in a `/api` docs page and link it from the footer.

### T3.4 — Directories & listings

Get listed where developers look: `awesome-llm`-style GitHub lists, LLM-tooling
directories, Product Hunt, Uneed/Smol Launch and similar. Deliverable: a
checklist with links and a one-paragraph standard description in
`docs/launch/directories.md`.

---

## Tier 4 — Retention (make traffic compound)

### T4.1 — Price-drop alerts

**Why.** Converts one-time searchers into a returning audience — the difference
between a tool people bookmark and one they forget. The earlier capture-only
demand probe (`signal_signups`) was removed, so this builds the alert feature
from scratch rather than reusing it.

**Steps.** Let visitors subscribe to "email me when a model I use changes price"
(and/or a Slack webhook). Reuse the changelog event stream from T2.1 as the
trigger. Start simple: email on any tracked-model price change, with a
preference for specific models later. Mind the secrets guidance in `CLAUDE.md`
(runtime secrets → Rails credentials).

**Done when.** A visitor can subscribe and receives a notification when a
selected model's price changes.

---

## Suggested order of execution

| # | Task | Effort | Payoff |
|---|------|--------|--------|
| 1 | T1.1 per-page meta descriptions | Low | Stops duplicate-content waste |
| 2 | T1.3 Search Console + Bing | Low | Measurement for everything else |
| 3 | T1.2 comparison pages | Med | Highest-intent query pattern |
| 4 | T2.1 changelog + RSS | Med | Fresh content + unique moat |
| 5 | T1.4 per-model OG images | Med | CTR on every share |
| 6 | T3.1/T3.2 Show HN + Reddit drafts | Low | Immediate qualified traffic |
| 7 | T3.3 embeddable badge | Med | Backlink engine |
| 8 | T2.2 "State of LLM pricing" report | Med | Backlinks / PR |
| 9 | T1.5 sitemap + FAQ schema | Low | Crawl quality, rich results |
| 10 | T4.1 price-drop alerts | Med | Retention |

Highest single leverage: **T1.2 comparison pages** (biggest empty surface
against the highest-intent queries). Cheapest mistake to fix: **T1.1 meta
descriptions**.

## Guardrails

- Keep the no-Node, server-rendered, inline-SVG ethos (see `CLAUDE.md`).
- All copy follows the `CLAUDE.md` voice rules: plain declaratives, specific
  numbers, no filler, no marketing constructions.
- Programmatic pages must carry real, unique value (price + history + verdict).
  Thin templated pages drag down the whole domain — generate a few hundred good
  ones, not thousands of shells.
- Run `bin/rails test` before pushing; tests that touch credentials stub them
  (`stub_admin_digest!`, `stub_anthropic_key!`).
- Don't post to external platforms (HN/Reddit/PH) without the owner's go-ahead —
  prepare drafts only.
