# Phase 1 spec — hang together

Implementation spec for the "hang together" phase of `docs/ROADMAP.md`.
Findings and rationale live in `docs/PRODUCT_ANGLE_REVIEW.md`; this document
is the build plan: five PRs, each independently shippable, ordered so the
most visible incoherence goes first. Copy strings below follow the copy
style in CLAUDE.md and are starting points — edit freely, the structure is
the spec.

Open decisions are marked **[decision]** with a recommendation; everything
else is settled.

---

## PR 1 — Global chrome and category-aware hero

### 1.1 Hero copy moves into the `ModelCategory` registry

Add three fields to the `Category` value object (`app/models/model_category.rb`):
`hero_eyebrow`, `hero_heading`, `hero_subhead` — the subhead a format string
with `%{models}` / `%{providers}` placeholders the view fills from the
category-scoped counts (`@category_counts[@category.slug]`, not
`@all_models_count` — today's hero counts every model while describing token
rates).

Proposed copy. The eyebrow states the tier honestly (tracked vs directory):

| Category | Eyebrow | Heading | Subhead |
|---|---|---|---|
| language | Live LLM API price index | LLM API pricing, tracked from launch. | %{models} language models across %{providers} providers — input, output, and cached rates per 1M tokens, updated daily, with full price history. |
| embeddings | Price directory — dated list prices | Embedding API pricing, per 1M input tokens. | %{models} embedding models — input rates and vector dimensions, dated and sourced from provider price pages. |
| rerank | Price directory — dated list prices | Reranker API pricing, in native units. | %{models} rerankers — priced per search or per 1M tokens; every price dated and sourced. |
| speech-to-text | Price directory — dated list prices | Speech-to-text API pricing, per minute of audio. | %{models} transcription models — native per-minute rates, dated and sourced from provider price pages. |
| text-to-speech | Price directory — dated list prices | Text-to-speech API pricing, per 1M characters. | %{models} speech models — native per-character rates, dated and sourced from provider price pages. |
| image | Price directory — dated list prices | Image generation API pricing, in native units. | %{models} image models — per image, per megapixel, or in credits; every price dated and sourced. |
| video | Price directory — dated list prices | Video generation API pricing, in native units. | %{models} video models — per second, per clip, or in credits; every price dated and sourced. |

The hero CTA ("How pricing works", `models/index.html.erb:322`) stays on the
language tab only — that page is per-token pedagogy. Directory tabs link to
`/sources` as "How prices are sourced". **[decision]** — alternative: keep
one CTA everywhere until the umbrella explainer exists; recommended as
specced, since a per-token guide under an image table is exactly the seam
this phase removes.

### 1.2 Layout defaults (`app/views/layouts/application.html.erb`)

- `:4` default title → `tokenprice.fyi — AI model API price index`
- `:5` default description → `AI model API prices — per token, per image,
  per minute of audio — for Anthropic, OpenAI, Google and 30+ providers.
  Full price history for language models; dated list prices across seven
  categories.`
- `:43` Organization JSON-LD description → `Independent price record of AI
  model APIs — per-token rates with full history for language models, dated
  list prices for embeddings, speech, image, and video.`
- `:137` footer tagline `List prices · USD per 1M tokens` → `List prices,
  in each API's billing unit`.

### 1.3 Page titles

- `comparisons/show.html.erb:2-3` → `Compare AI model API prices —
  tokenprice.fyi`; description mentions per-token rows for language models
  rather than claiming tokens for everything.
- `events/index.html.erb:1-2,10` → `Market events — AI model pricing &
  launch timeline`; "LLM market events" → "AI model market events".
- `price_changes/index.html.erb:1-2` → `Recent price changes — AI API price
  moves, last 30 days`.

### 1.4 llms.txt rewrite (`app/views/pages/llms_txt.text.erb`)

- Reframe the opening: independent price record of AI model APIs; state the
  two tiers in one sentence each.
- List all seven category tab URLs (iterate `ModelCategory.all`, as the
  sitemap does — no hardcoding).
- Update the blockquote summary and model/provider counts accordingly.

### 1.5 The rest of the chrome

- PWA manifest (`pwa/manifest.json.erb:19`) → `AI model API prices, tracked
  daily. Price history for language models; dated list prices across seven
  categories.`
- README: retitle and re-scope the opening paragraph and data-model section
  to the two-tier record framing.
- Learn index (`learn/index.html.erb:1-2,22-23` + `learn_helper.rb`): title
  → `Learn — how AI API pricing works`; lede states scope honestly: these
  explainers cover per-token pricing, where the complexity concentrates;
  billing units for the other categories are covered on their tabs (and by
  the umbrella explainer when it ships — phase 2).

**Acceptance:** every category tab renders its own hero with its own count;
no surface outside the language tab claims per-token units or full history
site-wide; llms.txt lists seven category URLs; grep for "LLM API price
tracker" and "per 1M tokens" finds only language-scoped uses.

---

## PR 2 — Small journey fixes

### 2.1 Reverse lookup on the registry

`ModelCategory.claiming(modality_class)` → `ALL.find { |c| c.member?(mc) }`.
(Language falls out via its `unclaimed?` fallback.) Used by 2.2, 2.4, and
PR 3/4.

### 2.2 Model-page breadcrumb (`models/show.html.erb:64`)

`← All models` → the model's own tab: label the category (`← Image
generation`), link via the category's `path_name` helper.

### 2.3 Untracked-price fallback (`models/show.html.erb:155-156`)

Add a `billing_noun` field to `Category` ("per image", "per second or per
clip", "per search or per 1M tokens", "per minute of audio", "per 1M
characters"; language: "per 1M tokens"). Fallback copy becomes `Priced
#{billing_noun} — not yet tracked` with the follow-on sentence built from
the same noun. Kills the video-model-described-as-per-image bug.

### 2.4 Events launch entries (`events/_event.html.erb:38-41`)

Branch: token-priced → `io_price` (today's line); `native_priced?` →
`price_headline`; neither → omit the price line entirely.

### 2.5 Model-page JSON-LD (`models/show.html.erb:47`)

`category: "LLM API model"` → the model's modality label (the same label
the badge renders).

### 2.6 `priced_as_of` on directory tables (`models/index.html.erb:663-672`)

In the `:native_price` and `:pricing` cells, append a muted `as of
<%= date %>` line when `priced_as_of` is present. The date is the honesty
mechanism — it belongs where the price is, not only on the show page.

### 2.7 Scroll preservation on tab switch

Thin Stimulus controller on the tab strip: record `window.scrollY` on tab
click (sessionStorage), restore once on the next `turbo:load` if the visit
came from the strip. No frames, no morphing — see the review appendix for
why full visits stay.

**Acceptance:** from an image model's page the breadcrumb returns to
/image-generation; an untracked video model says "per second or per clip";
a native-priced launch on /events shows its price headline; directory table
cells show their as-of date; switching tabs keeps the table in view.

---

## PR 3 — Provider pages group by category

`providers/show.html.erb:48-66` renders one hardcoded token table. Replace
with: group the provider's listed models with
`models.group_by { |m| ModelCategory.claiming(m.modality_class) }`, iterate
in `ModelCategory.all` order, render a labelled table per non-empty group
using that category's `columns`.

To avoid duplicating cell logic, extract the per-column cell rendering from
`models/index.html.erb:598-708` into a shared partial
(`app/views/models/_cells.html.erb`, taking `model:` and `columns:`) and use
it from both tables. The index keeps its select/compare chrome; the partial
owns only the data cells. This is the one real refactor in phase 1 — do it
in this PR, not PR 1, so the copy changes aren't hostage to it.

Also: the meta-description fallback (`providers/show.html.erb:3`) drops
"input/output rates per 1M tokens" for a category-neutral phrasing built
from the provider's actual category mix.

**Acceptance:** a provider with mixed categories (e.g. OpenAI, Google)
shows one table per category with no blank price columns; a token-only
provider looks unchanged; suite green after the partial extraction.

---

## PR 4 — Compare is scoped to one category

`comparisons_controller.rb` + `comparisons/show.html.erb`:

- Resolve model A (param, else default `claude-opus-4-8`). A's category
  (via `ModelCategory.claiming`) scopes the page: picker lists and model B
  candidates are that category's models only.
- If the `b` param names a model from another category, ignore it and fall
  back to A's category's second default. **[decision]** — alternative:
  render a "different billing units" notice instead of silently falling
  back; recommended as specced (silent fallback, URL corrects itself) since
  cross-category links in the wild are almost certainly accidents.
- Row shape by category: language keeps today's rows; embeddings → input
  /1M, dimensions, context, released, status; native-priced categories →
  price headline, pricing model, released, status, provider. Winner
  highlighting only on numerically comparable rows (input, native_price).
- Defaults per category (when arriving from a directory tab's compare
  button with only `?a=`): B = the category's cheapest-by-default-sort
  listed model that isn't A.
- The homepage compare tray (`compare_tray` controller) clears its
  selection when the category changes — selections must not cross tabs.

**Acceptance:** /compare?a=<image-model> renders an image-vs-image
comparison with no dash rows; hand-editing `b` to an embeddings slug falls
back cleanly; language compare is pixel-identical to today.

---

## PR 5 — Data layer stops contradicting itself

### 5.1 API native prices become numeric

`api/v1/models_controller.rb`: add `usd: m.native_price_usd, unit:
m.native_price_unit` to the `native_price` block. Replace the envelope's
`unit: "USD per 1,000,000 tokens"` with

```json
"units": { "price_per_mtok": "USD per 1,000,000 tokens",
           "native_price":  "USD per native_price.unit" }
```

**[decision]** — this drops the old `unit` key (breaking). Recommended now,
while consumers are few and the field is actively wrong for half the
catalog; alternative is emitting both for a deprecation cycle.

### 5.2 Native prices append instead of overwrite

New table `native_price_snapshots`: `ai_model_id`, `native_price_usd`,
`native_price_unit`, `pricing_model`, `price_summary`, `price_source`,
`priced_as_of`, timestamps. Concern `AiModel::NativePriceHistory`
(`app/models/ai_model/native_price_history.rb`): an `after_save` callback
appends a snapshot when any native pricing column changed
(`saved_change_to_*`). Covers every write path — seeds, candidate
acceptance, console — with no caller changes. Backfill: a data migration
creates one snapshot per model that has native pricing today, dated from
its `priced_as_of`. Nothing user-facing reads the table in phase 1; it
exists so the October re-verification pass deposits history instead of
destroying it.

### 5.3 Staleness gets a schedule

`PricingStalenessDigestJob` (thin, in the mould of the existing digest
jobs): runs `PricingStaleness`, and when anything is flagged posts counts
per category to Slack via `SlackNotifier` with a link to /sources. Add to
`config/recurring.yml`, weekly. Silent when nothing is stale.

**Acceptance:** API response validates for an image model (numeric price,
unit, no token claim); editing a native price in the console appends a
snapshot; the job posts to a stubbed webhook in tests and is present in
recurring.yml.

---

## Order and size

| PR | Size | Risk |
|---|---|---|
| 1 — chrome + hero | copy-heavy, one registry change | low |
| 2 — journey fixes | seven small independent edits | low |
| 3 — provider pages | one partial extraction + view rewrite | medium (the refactor) |
| 4 — compare scoping | controller + view row shapes | medium |
| 5 — data layer | one migration, one concern, one job, API shape | low, but 5.1 is the one breaking change |

Each PR: `bin/rails test` green, preflight before push. PRs 1–2 land the
visible coherence; 3–4 are the real view work; 5 can ship any time,
independent of the others.
