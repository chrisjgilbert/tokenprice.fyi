# Product angle review — July 2026

A review of where the product's framing has fallen behind its catalog, and a
plan for tightening it. Written after a full sweep of the copy, the category
machinery, the learn section, and the page-to-page journeys.

## Where the product actually is

The catalog is no longer an LLM price list. Seven categories ship today, each
with its own indexable URL, column shape, sort, and SEO copy, all driven off
the `ModelCategory` registry:

| Category | ~Models seeded | Billing unit | Price history? | Freshness |
|---|---|---|---|---|
| Language | ~81 (many retired/legacy lineage) | per 1M tokens | Yes — full snapshots | OpenRouter sync, daily |
| Embeddings | 18 | per 1M input tokens | Possible (input axis) | Partially synced |
| Image generation | 22 | per image / MP / credits | No | Manual (seed docs) |
| Text to speech | 18 | per 1M characters | No | Manual |
| Video generation | 17 | per second / clip / credits | No | Manual |
| Speech to text | 16 | per minute of audio | No | Manual |
| Rerank | 8 | per search or per 1M tokens | No | Manual |

Roughly 99 of ~180 seeded models are non-language. The recent commit history
points one direction: category tabs added one by one, the task Guide and tier
taxonomy removed, a curation pipeline added whose extractor already speaks all
seven category slugs. `docs/PRODUCT_VISION.md` frames the product as "the
price index". The catalog has followed that vision; the framing hasn't.

## The two-layer split

The audit found a clean fault line:

- **The per-category machinery is already right.** `ModelCategory` holds
  correct titles and meta descriptions for all seven tabs. The models table,
  sitemap, model-show pricing branches, curation extractor, and API response
  shape (per-token block + per-unit block + native-price block) are all
  category-aware.
- **Every global surface still says "LLM API token prices".** The hero
  (eyebrow, H1, subhead), the layout's default `<title>`/meta/OG, the
  Organization JSON-LD, the footer tagline ("USD per 1M tokens"), llms.txt,
  the PWA manifest, the README, and the page titles on /compare, /events, and
  /changes. The hero sits outside the category frame, so `/image-generation`
  renders "LLM API pricing, tracked from launch" above a table of per-image
  prices — and its subhead counts *all* models while describing "input,
  output, and cached rates per 1M tokens, updated daily, with full price
  history", which is untrue for five of seven categories.

So the product misdescribes itself twice over: it claims a narrower scope than
it has (LLM-only), and a deeper capability than it has (full history for
everything).

## Recommendation

Reposition the product as **the independent price index for AI model APIs**,
with per-token language pricing as its deepest, founding category — and make
the copy honest about the two depth tiers that actually exist:

1. **Tracked** — language models and embeddings: per-token rates, synced
   daily, full price history from launch.
2. **Priced directory** — image, video, speech, rerank: current list prices
   in each API's native billing unit, dated and sourced, manually verified.

This is a copy-and-seams repositioning, not a rebuild. The registry, routes,
table, and API already support it. Specifically, do not:

- **Rebrand the domain.** tokenprice.fyi is a founding-category name; brands
  outgrow literal names. What matters is that the surrounding copy stops
  doubling down on "per 1M tokens" as the site-wide unit.
- **Fake depth.** No history charts for directory categories until a real
  sync exists. The tightening is honest framing of the directory tier
  ("every price dated and sourced"), not pretending it's tracked.
- **Dilute the language tab's SEO.** The per-token pages keep their
  LLM-scoped titles — that's where the search volume and the pricing
  complexity live. The umbrella framing applies to the brand/default layer
  only.

## Pressure test (July 2026) — the hierarchy inverts

The positioning above was pressure-tested from three adversarial angles:
competitive (web research on the mid-2026 landscape), demand (who the user of
a cross-category directory actually is), and deliverability (what the
codebase can operationally sustain). The three attacks converged, and the
result amends this document's recommendation: **the scope survives, the
hierarchy doesn't.** "A pricing directory across AI models, with learning
resources" leads with the weakest asset. The defensible position is the
*record*: every price dated, sourced, and watched for changes.

### What the test found

**Competitive.** The LLM price-comparison space filled in over the last year.
pricepertoken.com owns the head SEO query with daily updates, ~300+ models,
its own pricing-history and trends pages, and an MCP server; BenchLM charts
LLM prices back to March 2023; LLMRates markets "the complete timeline" with
a changes-stream API. Cross-category current prices are open commons —
LiteLLM's community-maintained pricing JSON already covers embeddings, image,
STT, TTS, and rerank machine-readably; models.dev is an open cross-modality
database; Artificial Analysis publishes native-unit pricing for image, video,
and speech with a benchmark moat (but no price history, and its data API is
paid). Consequence: breadth is trivially replicable, "we track price
history" is no longer unique for LLMs, and generic pricing education is
commoditized. What remains unoccupied: **dated, sourced, from-launch history
combined with non-token categories and a curated events timeline explaining
why prices moved** — the price record of the AI API market.

**Demand.** Of the three jobs a pricing site serves — "what does X cost now,"
"did prices change," "which should I pick" — a directory serves only the
first, which is a one-visit commodity job (provider pricing pages answer
it). Field evidence (the pricepertoken Show HN thread) shows the community
explicitly asking for the second: history, detected price changes, more
categories, an API — nearly this product's asset list, which validates the
scope. But in the non-token categories, price spreads of 10–30× (video
$/sec, TTS $/1M chars) make "which should I pick" a quality question the
site deliberately doesn't answer, and Artificial Analysis already owns that
browse job. The cross-category "one user" is really seven thin audiences
whose SERPs are separately contested by vendor content teams. Education
demand is real but shallow, LLM-specific, and functions as calculator-funnel
spokes elsewhere — a supporting surface, not a positioning clause. Trust
compounds the risk: pricing sites get judged by their worst cell, and one
stale directory price teaches a visitor to distrust the "synced daily" claim
beside it.

**Deliverability.** The directory tier's post-seed lifecycle currently runs
on maintainer memory: price updates require editing the pricing doc and
seeds, then a deploy plus `bin/kamal seed` (no admin edit path — native price
fields are unpermitted in `admin/models_controller.rb`); `PricingStaleness`
is well-built and covers every directory category but is a manual rake task,
absent from `config/recurring.yml`, with no Slack alert; `priced_as_of` is
user-visible only on the model show page and in one API field. The API
serves directory categories a prose `summary` string (numeric
`native_price_usd`/`native_price_unit` are omitted) under an envelope
claiming `unit: "USD per 1,000,000 tokens"`. Structurally worst: native
price updates **overwrite** the columns on `ai_models`, so the manual tier
can never accumulate history — it consumes owner attention while depositing
nothing into the asset the vision monetizes. And because the whole tier was
seeded in the same week (2026-07-01/06), all ~80 directory prices cross the
90-day staleness threshold together in early October.

### The amended positioning

> **The price record of AI model APIs: every price dated, sourced, and
> watched for changes — with full from-launch history for language models,
> and history for the other categories beginning when tracking begins.**

"Tracked" becomes the admission criterion for headline claims. The directory
tier is framed as the watchlist frontier ("current list prices, dated and
sourced; history begins when tracking does") rather than a co-equal
directory. Learn stays a supporting surface and leaves the positioning
statement. The two assets no competitor combines — provenance-grade history
across categories, and the curated events narrative — move to the front.

### What this changes in the plan

Three operational items are promoted from footnotes to the top of the
priority order, because the amended positioning depends on them:

1. **Append, don't overwrite, native prices.** When `native_price_usd` /
   `price_summary` changes, record a dated snapshot instead of destroying
   the prior value. This is the cheapest structural move in the plan and
   the only one whose value compounds: it converts the October
   re-verification cliff into the directory tier's first history data, and
   history-across-categories is the one combination no competitor holds.
2. **Close the staleness loop.** Schedule `PricingStaleness` weekly in
   `config/recurring.yml` and post flagged counts to Slack via the existing
   `SlackNotifier` — a thin job around an already-tested PORO. Surface
   `priced_as_of` on the directory tab tables, not just the show page.
3. ~~Make the API machine-readable for every category.~~ **Superseded (July
   2026): the public JSON API was removed instead.** The pressure test
   surfaced the API's incoherence (a token-unit envelope over native prices);
   the resolution was to delete the endpoint rather than fix it, since
   current-price APIs are a commodity (LiteLLM, models.dev) that seeded no
   flywheel worth its maintenance. The `PriceCatalog` seam stays internal.
   See the `PRODUCT_VISION.md` July update.

The demand evidence also names the natural next feature: "tell me when
prices change" was the most-requested capability in the field research. The
raw machinery exists (/changes, the Slack digest); a public-facing change
feed (email or RSS) is the shortest path from the record to a
return-visit habit, and is noted here as a candidate rather than a
commitment.

### Calibration — this is a passion project

The stakes above should be read against the actual goals: a product the
owner is proud of, some traffic, and low maintenance — not winning a
category. That calibration changes the weighting, not the conclusions:

- **The competitive urgency evaporates; the positioning inversion doesn't.**
  There is no race against pricepertoken or Artificial Analysis to lose. But
  the record framing survives on the pride axis alone: a dated, sourced
  record is a crafted thing that is *right*; a me-too directory competing on
  breadth is neither. It also happens to be the lowest-maintenance
  positioning — a record's tracked tier accumulates automatically, and its
  manual tier stays honest by being dated rather than by being constantly
  fresh. An "as of March" price is a true statement in July; an undated
  price is a wrong one.
- **The operational trio survives because it *reduces* maintenance, not
  because it wins anything.** The staleness alert turns "remember to check"
  into a bounded, scheduled chore; append-only snapshots mean the manual
  work compounds instead of evaporating. (The third former item — the API
  fix — was removed instead of fixed; see the July note above.)
- **Stagger the re-verification instead of eating the October cliff.**
  Rotate one directory category per month (~8–22 rows, an evening): each
  category gets re-verified roughly twice a year, which matches how often
  these prices actually move, and no month is heavy.
- **The pride items are the journey fixes**, independent of any traffic
  argument: the compare table of dashes, the provider page's blank cells,
  the video model described as "priced per image", the hero claiming token
  rates over an image table. Those are the difference between a product
  that holds together and one that shows its seams.
- **Traffic, realistically**, comes from surfaces with zero marginal
  maintenance: the per-model and per-category pages (built), llms.txt as a
  citation target (built), an RSS change feed off /changes (cheap, no
  subscriber support burden — prefer it over email), and occasional
  launch/show-and-tell posts. Not from fighting seven vendor-owned SERPs.
- **Guard the maintenance budget explicitly.** Recurring human work should
  stay at: reviewing model candidates (minutes), curating market events
  (discretionary, the editorial habit), one category re-verification pass a
  month, and glancing at a weekly staleness ping. Anything that adds a
  standing obligation — per-category explainers beyond the umbrella piece,
  an email product, breadth-chasing — should be treated as out of budget
  until something proves it's worth the trade.

- **Hero** (`app/views/models/index.html.erb:300-313`): make it read from the
  current category. `ModelCategory` already carries per-tab copy; add hero
  strings there (eyebrow / H1 / subhead per category). The language tab keeps
  something close to today's hero; the site-wide *claim* moves to something
  like "AI model API prices, in each API's billing unit" only where a neutral
  default is needed. Per-tab subheads state that tab's model count and unit,
  and only the tracked tier claims "full price history".
- **Default title/meta/OG** (`app/views/layouts/application.html.erb:4-5`):
  e.g. "tokenprice.fyi — AI model API price index" / "AI model API prices —
  per token, per image, per minute of audio — for Anthropic, OpenAI, Google
  and 30+ providers. Price history for language models; dated list prices
  across seven categories."
- **Organization JSON-LD** (`application.html.erb:43`): same re-scope.
- **Footer tagline** (`application.html.erb:137`): "List prices · USD per 1M
  tokens" → drop the unit claim ("List prices · sourced from provider price
  pages" already exists on the next line) or state the tiering.
- **llms.txt** (`app/views/pages/llms_txt.text.erb`): currently LLM-only and
  omits the six category URLs entirely — the citation-flywheel page doesn't
  mention half the catalog. List all seven tab URLs and describe the two
  tiers.
- **PWA manifest** (`app/views/pwa/manifest.json.erb:19`) and **README**:
  same re-scope.
- **Page titles on /compare, /events, /changes**: "LLM" → category-neutral
  ("Compare AI model API prices…", "AI model launches & market events…").

## Workstream 2 — Stop the category leaks in journeys

Category context is currently lost the moment a user leaves the homepage:

- **Model show breadcrumb** (`app/views/models/show.html.erb:64`): hardcoded
  "← All models" → root. Point it at the model's own category tab.
- **Provider page table** (`app/views/providers/show.html.erb:48-66`):
  hardcoded Input/Output/Context columns render blank cells for a provider's
  image/speech/embedding models, and the meta fallback promises "input/output
  rates per 1M tokens" for providers with no token models. Group the
  provider's models by category and reuse the category column shapes.
- **Compare** (`comparisons_controller.rb`, `comparisons/show.html.erb`):
  pickers list every model, so an embeddings-vs-video compare renders a table
  of dashes with meaningless "winner" highlights. Cheapest coherent fix:
  scope picker B to picker A's category, and for native-priced pairs render
  price headline + pricing model + released instead of the per-token rows.
- **Events launch entries** (`app/views/events/_event.html.erb:38-41`):
  render per-token I/O price for every launch, empty for directory models.
  Render `price_headline` for native-priced models instead.
- **Untracked fallback on model show** (`show.html.erb:155-156`): the
  "priced per image, not per token" copy is the else-branch for *every*
  untracked category — a video model gets image copy. Read the unit from the
  category.
- **Model-show JSON-LD** (`show.html.erb:47`): `category: "LLM API model"`
  hardcoded for every model, including image/video Product schema. Use the
  modality label.
- ~~**API envelope**~~: the top-level `unit: "USD per 1,000,000 tokens"`
  header contradicting the `native_price` blocks was one of the clearest
  incoherences here — resolved (July 2026) by removing the public API
  entirely rather than reshaping it. See the July note above.
- **/changes inbound link**: off-nav and off-sitemap is deliberate, but its
  only entry point is the Slack digest. One inline link from /events ("the
  raw feed behind this timeline") makes it durable.

## Workstream 3 — Learn section

The learn layer is entirely per-token: all four explainers, the
how-pricing-works page, the io-ratio widget (which excludes non-token models
incidentally, via an input-and-output presence filter), and the feature-costs
picker (same filter). None of it links to any category tab.

- **Keep the four explainers as they are.** They're accurate, deep, and cover
  the category where pricing is genuinely hard (input/output split, caching,
  reasoning tokens). Don't dilute them with category asides.
- **Re-lede the learn index** (`learn/index.html.erb`, `learn_helper.rb`):
  title/lede currently claim to explain "LLM API pricing" as if that were the
  whole product. Describe the coverage honestly: these explainers cover
  per-token pricing, where the complexity concentrates.
- **Add one umbrella explainer**: "Billing units across AI APIs" — per token,
  per image, per minute, per character, per second; why per-token needs five
  dimensions while per-image is a sticker price; why cached input exists only
  for token models; why some categories resist comparison (rerank's
  per-search vs per-token split). It becomes the natural first entry and the
  page every category tab can cross-link.
- **Label the feature-costs picker** as language models (it already is, via
  the price-shape filter — say so rather than leaving it implicit).

### Per-category explainers — a demand-gated follow-on

The categories don't all earn the same treatment, because they don't carry
equal pricing complexity:

- **Image + video generation** have the most explanatory substance: per-image
  vs per-megapixel vs credit packs, resolution and duration tiers, why a
  "$0.04/image" sticker and a credit plan resist comparison. The seed data
  already carries the structure (`pricing_model` / `price_summary` /
  `price_detail`) — the explainer is the editorial version of why those tabs
  show a "Pricing" string column instead of a sortable number. One combined
  "how generation APIs price" piece is defensible; two if they diverge.
- **Speech** (one piece covering STT and TTS): the genuinely non-obvious trap
  is the same capability priced in different units across providers — per
  minute of audio at Deepgram/AssemblyAI vs audio tokens at OpenAI — plus
  feature tiers (streaming vs batch, diarization) and TTS's per-character vs
  per-second split.
- **Embeddings**: almost too simple for a standalone page (one meter, input
  only). The interesting material is adjacent — dimensions vs cost, and that
  the recurring bill is usually the vector store, not the embedding call. A
  section of the umbrella piece unless traffic argues otherwise.
- **Rerank**: two paragraphs inside the umbrella explainer, not a page.

Sequencing: umbrella first — it covers the educational gap at a fifth of the
maintenance surface and tells you from traffic whether the deeper pieces are
wanted. Then generation (image/video), then speech, then embeddings if its
umbrella section outgrows itself.

Structural notes for when these ship:

- **Group the learn index** into "Per-token pricing" (the existing four) and
  "Other billing units". A flat seven-card list stops scanning, and the
  grouping makes the LLM material read as deliberately scoped rather than
  accidentally narrow.
- **New widget plumbing needed**: the existing widgets filter on per-token
  price presence, so they structurally exclude these categories. Category
  pieces want a simpler strip — min/median/max off the category's
  `price_headline` values — which `PriceCatalog` entries can already feed.
- **Prefer live entries over hardcoded worked examples.** Directory prices
  are manually maintained; the hardcoded RAG math in the existing pieces ages
  more gracefully than a hardcoded image price would. Lean on live entries
  and their `priced_as_of` dates.
- **Honest counterweight**: every explainer is a maintenance commitment in a
  hand-maintained tier of the catalog. That's the argument for the
  demand-gating above.

## Workstream 4 — Say the depth tier out loud

The tracked/directory split exists in the schema (`price_points` vs
`native_price_usd`/`price_summary` + `priced_as_of`) but nowhere in the copy.
Surface it:

- Hero subheads per tier (workstream 1).
- Directory tabs: a one-line note above the table — current list prices,
  dated, sourced from provider price pages, no history yet.
- /sources: describe the two maintenance paths (synced daily vs manually
  verified against the seed docs). This is a strength framed correctly —
  "every price dated and sourced" — and a misrepresentation framed as today's
  silent uniformity.

## Benchmarks — a future quality layer (researched July 2026)

The owner intends to eventually fold in benchmark scores as a quality
indication. This is coherent with the product's identity on one condition:
**quality numbers enter the same way prices do — as sourced, dated,
attributed third-party measurements, never the site's own verdict.** That is
also the clean narrative for why benchmarks can come in after the tier
taxonomy went out: tier was the site's own unsourced opinion; a cited score
is someone else's measurement with provenance. And it answers the demand
test's sharpest finding — in the directory categories, 10–30× price spreads
make price-only tables misleading, which is precisely where a quality signal
earns its column.

Web research on ingestible sources (machine-readable, licensed for
attributed republication, low-maintenance):

| Category | Best source | Format / license | Notes |
|---|---|---|---|
| Language | Arena leaderboard dataset (`lmarena-ai/leaderboard-dataset` on HF) | Parquet, `latest` + historical splits, **CC-BY-4.0** | One dataset also covers image and video arenas — one ingestion job, four categories |
| Language (static evals) | Epoch AI Benchmarking Hub | CSV/ZIP + Python client, **CC-BY** | Per-score provenance model matches this site's exactly |
| Image gen | Arena dataset `text-to-image` subset | as above | |
| Video gen | Arena dataset `text-to-video` / `image-to-video` subsets | as above | VBench is Apache-2.0 but research-checkpoint-skewed |
| Embeddings | MTEB results (GitHub JSON / HF parquet) | machine-readable; **license unconfirmed** — one clarifying issue before republishing | Covers commercial API embedders |
| STT | Open ASR Leaderboard | CSVs in an **Apache-2.0** repo | Snapshot-based cadence; commercial-API coverage partial |
| TTS | TTS Arena V2 | HTML only, no dataset/API — ask maintainers | Honest gap |
| Rerank | — | — | No neutral machine-readable source; mostly vendor self-reported. Show "no independent score" |

Artificial Analysis has the best commercial coverage (including TTS/STT) and
catalog-friendly slugs, but its free API tier is licensed "internal use only
with attribution" and redistribution is a commercial-tier conversation —
blocked pending their permission, not a default ingredient.

Presentation rules when this ships: every score carries benchmark name,
snapshot date, and a link; arena Elo (preference-based, gameable — see the
Llama-4-Maverick episode and "The Leaderboard Illusion" paper), static-eval
accuracy (contamination-prone), and usage rankings (OpenRouter throughput —
adoption, not quality) are labeled as different kinds of signal, not blended
into one number. Model-name-to-slug mapping needs a small alias table
(date-suffixed arena names); that is the main one-time cost. Ingestion is a
scheduled job in the `ModelSync` mould — no self-run benchmarks, ever.

Bottom line: feasible, low-maintenance, and provenance-compatible. Start
with the Arena dataset when the time comes; it is CC-BY-4.0 and covers four
categories in one job. Pinned behind the coherence and growth work.

## Appendix — category-switch mechanics (full visit vs partial update)

Today's behaviour, for the record: Turbo Drive is active site-wide
(`app/javascript/application.js` imports `@hotwired/turbo-rails`; nothing on
the tab links opts out), so a tab click is already a Drive visit — a fetch
plus body swap, not a browser reload. What reads as a "full page reload" is
the whole-body swap: the hero and header re-render, and scroll resets to the
top, above a tall hero the reader then has to scroll back past. Meanwhile
filter and sort changes *within* a tab are already partial updates — the
filters form targets `turbo_frame_tag "models"` with `turbo_action:
"replace"` (`models/index.html.erb:428,506`). The seam between "new page"
(category) and "same page, new query" (filters) is deliberate and correct.

Options, ranked:

1. **Keep full visits; fix the jank (recommended).** A category switch
   changes nearly everything meaningful — title, meta, canonical, JSON-LD,
   columns, sorts, and (after workstream 1) the hero — so "new page" is the
   right semantic. The dominant irritation is the scroll reset past the hero,
   which a small sprinkle fixes: on tab-strip clicks, capture scroll position
   and restore it after `turbo:load`. Cheap, no restructuring, no SEO risk.
2. **Cross-URL morphing, if the swap-flash itself is the complaint.** Turbo 8
   only morphs refresh visits (same URL), but a `turbo:before-render`
   listener can substitute a morph render for tab navigations. Full-visit
   semantics are preserved (head tags update correctly), unchanged regions
   (header, footer, hero until workstream 1) don't repaint, and scroll holds.
   Caveat one: it's a hand-rolled deviation from "thin glue around the
   platform" and needs saying why. Caveat two: anything that survives the
   morph survives *across categories* — the compare tray's selection
   currently resets on tab switch precisely because the visit is a full swap;
   a morph (or frame) approach must explicitly clear the tray on category
   change or it enables the cross-category compares workstream 2 guards
   against.
3. **Frame-based tabs — not recommended.** Pointing the tab links at a frame
   leaves stale everything outside it: document title, canonical, the filters
   form's category-scoped action URL, the active-tab highlight, and the
   category-aware hero workstream 1 introduces. Fixing that means moving the
   tab strip, filters, and hero inside the frame plus a title-sync hack — at
   which point the frame spans the page and Drive has been reimplemented with
   extra steps.
4. **Client-side tabs (preload all categories) — rejected.** Seven tables in
   one DOM, and it breaks the URL-per-category architecture (own canonical,
   meta, JSON-LD per tab) that the routes and sitemap are built on. The
   existing view comment (`models/index.html.erb:407`) already records this
   decision; it stands.

Interaction with workstream 1: the more category-aware the chrome becomes,
the less a partial update buys — once the hero varies by category, almost
nothing above the table is category-invariant. That is the quiet argument
for option 1.

## Suggested order (amended after the pressure test)

1. Append-only native price snapshots + scheduled staleness alerts (the
   pressure test's promotions — small, structural, compounding).
2. Workstream 1 (global chrome + category-aware hero), written to the
   amended positioning: record/tracker first, "tracked" as the admission
   criterion for headline claims.
3. llms.txt category listing (the API removal that formerly shared this
   step is done — see the July note above).
4. The small leak fixes in workstream 2 (breadcrumb, untracked fallback,
   JSON-LD category, events price line) — each is a few lines.
5. Provider page and compare re-shaping — the two real view changes.
6. Learn re-lede + the umbrella explainer.
