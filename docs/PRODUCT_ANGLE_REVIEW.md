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

## Workstream 1 — Re-scope the global chrome (highest leverage)

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
- **API envelope** (`api/v1/models_controller.rb`): the top-level
  `unit: "USD per 1,000,000 tokens"` header contradicts the `native_price`
  blocks in the same response. Move unit semantics into the per-model blocks
  (or document per-block units) and consider a `category` filter param.
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

## Suggested order

1. Workstream 1 (global chrome + category-aware hero). One PR, fixes the
   headline misdescription everywhere at once.
2. The small leak fixes in workstream 2 (breadcrumb, untracked fallback,
   JSON-LD category, events price line) — each is a few lines.
3. Provider page and compare re-shaping — the two real view changes.
4. Learn re-lede + the umbrella explainer.
5. API envelope + llms.txt category listing.
