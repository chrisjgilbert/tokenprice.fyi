# SEO audit — tokenprice.fyi

*Audited against `main` @ a418c20 (Model Guide Phases 0–2 shipped). Five parallel specialist passes:
on-page metadata, structured data, crawlability/indexability, content/internal-linking, and
performance/Core Web Vitals. Findings are deduplicated and prioritized below; issues flagged by more
than one pass are the highest-confidence.*

## Headline

The **deep pages are well-built** — model pages (`/models/:id`) and guide task pages (`/guide/:task`)
have dynamic titles, JSON-LD, and correct canonicals. The weaknesses cluster in four places:

1. **The front door** (homepage) is paradoxically the weakest-optimized page.
2. **Duplicate-content sinks** — chiefly `/compare` permutations.
3. **The strategic bet is under-resourced on-page** — the "best LLM for X" guide pages are thinner
   than the `feature-costs` explainer that targets the same queries.
4. **One Core Web Vitals lever** — render-blocking fonts.

Crawl fundamentals are otherwise strong: the `/which-model`→`/guide` 301 is correct, unknown
`/guide/:task` returns a real 404, admin is noindexed, and there are no orphan pages.

---

## Action list (prioritized)

### Tier 1 — Do first (high impact)

| # | Fix | Why | Where |
|---|---|---|---|
| 1 | **Canonicalize `/compare` to one param-free URL** (or noindex when params present) | ~1,600 thin near-duplicate `?a=&b=` permutations are indexable with no canonical — the worst duplicate/crawl sink. *(metadata + crawl)* | `app/views/comparisons/show.html.erb` (add `content_for :canonical, compare_url`) |
| 2 | **Fix the homepage** | No owned meta description (inherits the layout default); the decision-bridge H1 contains no "LLM"/"pricing" keywords and fights its own title; canonical still splits on `?tier=`. *(metadata + content)* | `app/views/models/index.html.erb` (add `content_for :description`; add a keyworded H2/intro; drop `tier:` from the canonical on line 3) |
| 3 | **Deepen guide task pages + split intent vs `feature-costs`** | The "best LLM for RAG/coding/chatbot" bet rests on pages thinner than `feature-costs`, which targets the same entities — Google may rank the explainer or split equity. *(content — the biggest strategic gap)* | `app/views/guide/show.html.erb`, `app/helpers/guide_helper.rb`; reframe `feature-costs` to "cost breakdown" intent |
| 4 | **Self-host/preload fonts (or load non-blocking)** | The render-blocking Google Fonts `<link>` is the single biggest CWV lever — homepage LCP (H1 text) waits on a third-party round trip + 8 WOFF2 files. *(performance)* | `app/views/layouts/application.html.erb:18-20` |
| 5 | **Thicken provider pages** | Thinnest template in the app — no description, canonical, JSON-LD, or intro prose; pure duplicate-risk of `/?provider=x`. *(metadata + content)* | `app/views/providers/show.html.erb` |

### Tier 2 — High-value follow-ups

| # | Fix | Why | Where |
|---|---|---|---|
| 6 | **Swap deprecated `HowTo` → `FAQPage`** | `HowTo` rich results were retired by Google (2023); FAQ is the live win for "best model for X / what does X cost" + AI-overview eligibility | `app/views/guide/show.html.erb`, learn explainers |
| 7 | **Sitewide `Organization` + `WebSite` + `SearchAction`** | Cheap; unlocks the sitelinks search box and entity grounding on every page | a `:head` partial in `app/views/layouts/application.html.erb` |
| 8 | **`Dataset` schema** pointing at the JSON API as `DataDownload` | Google Dataset Search inclusion — serves the stated API citation/backlink flywheel | `app/views/sources/index.html.erb` and/or `trends` |
| 9 | **Internal links: homepage → task pages + `/learn`; model → guide CTA; provider → guide/trends** | The homepage passes no equity to the bet pages. NB: the **"Price this in the guide" CTA was in the copy deck but didn't ship** — a build gap, not just SEO | `models/index.html.erb`, `models/show.html.erb`, `providers/show.html.erb` |
| 10 | **`<lastmod>` from last price change, not `released_on`** | Sitemap signals model launch date; use `current_price&.effective_on` so daily updates become a real freshness signal. Add `<lastmod>` to the homepage URL too | `app/views/sitemaps/index.xml.erb:21` |
| 11 | **Lazy-load the trends chart controller** | `eagerLoadControllersFrom` ships `trends_chart_controller.js` (34.7 KB, ~72% of controller JS) on every page though only `/trends` uses it | `app/javascript/controllers/index.js` |
| 12 | **OG image SVG → 1200×630 PNG; fix `og:url` to mirror canonical** | SVG OG images don't render on Twitter/Slack/LinkedIn; `og:url` currently leaks query params, undercutting canonicals | `app/views/layouts/application.html.erb:13-16` |

### Tier 3 — Quick wins (batch)

- **Add `/learn/anatomy` to the sitemap** — it's orphaned from it. *(crawl + content)* `app/views/sitemaps/index.xml.erb`
- **`/guide/coding_agent` → `/guide/coding-agent`** — the underscore breaks the site's hyphen convention and weakens tokenization (keep `coding_agent` as the internal `FeaturePattern` key, map the slug).
- **Target US "summarization"** in the visible heading — higher volume than the shipped British "Summarisation". `app/models/feature_pattern.rb:253`
- **Add missing canonicals/descriptions** to `/trends`, `/sources`, `/how-pricing-works`, `/models/:id` (each falls back to `request.original_url`).
- **robots.txt:** `Disallow: /api` and `/up`. `public/robots.txt`
- **Conditional GET** (`fresh_when` ETag/Last-Modified) on `models#index`, `guide`, `pages` for crawl budget on a daily-updated site.
- **Use the configured Solid Cache** — `perform_caching` is on but no view has a `cache` block; wrap the model table and `_io_ratio_widget`.
- **Branded 404** — replace default `public/404.html` with links back into the site.
- **Trim font weights** from 4→2 per family where usage allows (~halves font transfer).
- **JSON-LD correctness:** convert raw inline JSON on `how_pricing_works` to the `json_ld` helper; single `Offer` → `AggregateOffer` on model pages (note: Product price rich results are not granted for per-token API pricing, but this clears Search Console warnings).

---

## Detailed findings by area

### On-page metadata
- Deep pages strong: `/models/:id` (dynamic title + description + Product/Breadcrumb JSON-LD), `/guide/:task`
  (dynamic title, correct canonical, keyword H1).
- Homepage is the weakest: no owned `content_for :description`; canonical `root_url(tier: @tier)` keeps
  `?tier=` (3 thin self-canonical states); H1 omits "LLM"/"pricing". *(`models/index.html.erb:1,3,327`)*
- `/compare`: dynamic title varies by `?a=&b=` on one URL; no description, no canonical; H1 ("Compare two
  models") mismatches the dynamic title. *(`comparisons/show.html.erb`)*
- Site-wide OG/Twitter weak: single static `og.svg` (poor social support), `og:url` = `request.original_url`
  (leaks params), no `og:site_name`. *(`layouts/application.html.erb:13-17`)*
- Missing canonicals on `/models/:id`, `/providers/:id`, `/trends`, `/sources`, `/how-pricing-works`
  (fall back to `request.original_url`). `/providers/:id` also has no description.

### Structured data (already partly shipped via the `json_ld` helper)
- Present: `ItemList` (home, guide index, learn index), `Product`+`Offer`+`BreadcrumbList` (model),
  `HowTo` (guide task), `Article` (explainers), `WebPage` (sources).
- Gaps: no sitewide `Organization`/`WebSite`/`SearchAction`; `HowTo` is deprecated (→ `FAQPage`); no
  `Dataset` for the price data; no schema on provider/compare/trends.
- Correctness: `how_pricing_works.html.erb:5` hardcodes raw JSON (bypasses helper escaping); model `Offer`
  uses a single `price: current_input` while the product has input+output (→ `AggregateOffer`).
- All recommended schema is populatable from existing model data — no new data collection needed.

### Crawlability / indexability
- Strong: 301 correct, unknown task → real 404, admin noindex + robots Disallow, no orphans, guide task
  pages correctly in the sitemap and canonicalized.
- Issues: `/compare` permutations uncanonicalized (~1,600 dupes — most damaging); `/learn/anatomy` missing
  from sitemap; `<lastmod>` uses `released_on` not last price change; `?tier=` states in duplicate limbo;
  `/api` and `/up` not in robots.

### Content / internal linking
- Guide task pages have **strong intent match** on the head terms but **thin unique text** (lede + 3 drivers
  + takeaway), and **cannibalize `feature-costs`** — the deepest page in the app, targeting the same five
  task entities on one URL. This is the biggest strategic content gap: the bet pages are weaker than the
  informational page meant to support them.
- Homepage links only to the guide *index*, not task pages or `/learn` — passes no equity to the bet pages.
- Provider pages are thin and near-orphan for inbound equity.
- Model pages don't link to the guide (the copy-deck "Price this in the guide" CTA didn't ship).
- Slug/spelling: `/guide/coding_agent` underscore; "Summarisation" vs higher-volume "summarization".

### Performance / Core Web Vitals
- Already good: Propshaft fingerprinting + 1-year cache headers, Tailwind v4 tree-shaking to one file,
  no content images / no heavy SVGs (world map confirmed removed), fully server-rendered live widget (no
  CLS), viewport + mobile tap targets, `<html lang>`, HTTPS/HSTS, Cloudflare in front.
- Needs work: render-blocking Google Fonts (biggest LCP lever) + 8 WOFF2 files; eager-loaded 34.7 KB trends
  chart on every page; no conditional GET (ETag/Last-Modified) on public controllers; Solid Cache configured
  but unused; default unbranded 404.

---

## What's already good (don't relitigate)

Deep-page metadata and JSON-LD; correct 301/404; admin noindexed; no orphan pages; guide task pages in the
sitemap and canonicalized; homepage strips sort/dir params from canonical; Propshaft + long-cache assets;
Tailwind tree-shaking; no heavy images/SVGs; server-rendered live widget; mobile-ready; HTTPS + Cloudflare.
For a lean server-rendered Rails app this is a solid baseline — the work is concentrated in the front door,
the duplicate sinks, the depth of the strategic pages, and the font path.
