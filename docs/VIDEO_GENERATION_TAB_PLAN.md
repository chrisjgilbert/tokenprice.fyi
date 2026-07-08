# Video generation category tab — plan

> The fifth pricing-table category, after Language · Embeddings · Speech to text ·
> Image generation. Video generation is **image-generation-shaped**: it's a
> directory class with heterogeneous native pricing (per second, per clip,
> resolution/duration/audio tiers, credits), so it reuses image's column set,
> `:pricing` cell, and `price_summary`/`pricing_model` machinery wholesale rather
> than STT's single sortable per-minute rate. Companion to
> `docs/IMAGE_CATEGORY_PLAN.md` and `docs/SPEECH_TO_TEXT_TAB_PLAN.md`.

## Why this is the cheapest category to add yet

The category system is meant to make a new tab "a registry addition plus a
route — the controller, view, and sitemap read everything they need off the
category" (`ModelCategory` docstring). Speech-to-text still cost real new
infrastructure — a numeric `native_price_usd` column, a sortable `native_price`
column in the view, a generalized sort sink. Video needs **none of that**,
because it shares image generation's shape:

- Heterogeneous native pricing → the existing `price_summary` (string) +
  `pricing_model` (badge) columns, already on `AiModel`.
- The `:pricing` view cell already renders priced / native / untracked, reads
  through `price_headline`, and shows the `pricing_model_label` badge.
- The sitemap is now registry-driven (loops `ModelCategory.all`), so a new tab
  needs **no sitemap edit** — and the "lists every category tab URL off the
  registry" test auto-covers it.

So the diff is: a modality rule, two `PRICING_MODEL_LABELS`, a `ModelCategory`
entry, a route, SEO copy, and seeds. That's the design paying off.

## The one open decision — how to represent price

Video pricing is genuinely tier-heterogeneous. The same model often costs
different amounts at 720p vs 1080p vs 4K, at 5s vs 10s, and with vs without
generated audio (Veo 3's audio track is the canonical example). Two options:

- **(A, recommended) Image-style `price_summary` strings, not price-sortable.**
  Each row carries a native `price_summary` like `"$0.40/sec (720p) · $0.75/sec
  (1080p)"` or `"$0.05 / sec"` or `"credits"`, plus a `pricing_model` badge.
  Columns and sorts are image's exactly (`name`, `provider`, `released`). This
  is honest about the tiers, needs zero new storage, and maximizes reuse. A
  clean single-rate model can *optionally* also set `native_price_usd` + `"/sec"`
  so `price_headline` renders `"$0.05 /sec"` — the existing cell already prefers
  it — but the column stays non-sortable, since mixing a sortable number with
  tiered strings would rank a `"$0.40–$0.75/sec"` row against a flat `"$0.05/sec"`
  one and mislead.

- **(B) A sortable `$/sec` column like STT.** Forces every row to one number.
  Rejected for v1: it would fudge the resolution/audio/duration tiers into a
  single figure, which is exactly the "show it how it is, don't fabricate a
  comparable number" line we've held. Revisit only if the roster turns out to be
  mostly clean single-rate models.

**This plan assumes (A).** It's the honest, cheap, high-reuse choice; flag if
you'd rather force a sortable per-second number.

## Classification

`ModalityClass` gains a `video_generation` rule, symmetric to `image_generation`:

```ruby
# in SIGNATURE_RULES, immediately after image_generation:
image_generation: -> { @output.include?("image") },
video_generation: -> { @output.include?("video") },
```

- `[text] → [video]` (text-to-video), `[text, image] → [video]`
  (image-to-video), `[image] → [video]` → **video_generation**. These classify
  as `:other` today, so this is a pure widening — no existing row silently
  reclassifies (verified against the taxonomy test).
- `[text, video] → [text]` (video *understanding*) stays **multimodal**: video
  is an *input*, text the output — exactly the STT-style asymmetry (audio-in
  transcription vs audio-out speech). Symmetry: video **output** = generation,
  video **input** = multimodal understanding.
- The `[image, video]` dual-output edge is theoretical (no such model). Placing
  `video_generation` right after `image_generation` means a hypothetical
  image+video output matches `image_generation` first; acceptable and documented.

Also:
- `LABELS[:video_generation] = "Video generation"`
- `DESCRIPTIONS[:video_generation] = "Text (and optionally an image) in, a video out."`
- `DIRECTORY_CLASSES` gains `:video_generation` (listed without a per-token
  price; reads "not yet tracked" until curated).

No `VOCABULARY` change — `video` is already in the closed vocabulary.

## Storage

**None.** Reuses the curated native-pricing columns already on `AiModel`
(`pricing_model`, `price_summary`, `price_detail`, `price_source`,
`priced_as_of`) and — optionally, for clean single-rate models — the existing
`native_price_usd` / `native_price_unit`. No migration.

`AiModel` predicate additions (mirroring `speech_to_text?`):
- `def video_generation? = modality_class == :video_generation`

Add to `PRICING_MODEL_LABELS`:
- `"per_second" => "Per second"`
- `"per_video"  => "Per video"`

(`per_image_tiered`, `credit_based`, `token_based` already exist and are reused
as-is for tiered / credit / token-metered video models.)

`native_priced?`, `directory_listing?`, and `price_headline` already handle
video with no change — `native_priced?` is `price_summary.present? ||
native_price_usd.present?`, and `directory_class?` will return true for the new
class. `PriceCatalog::Entry` stays in lockstep automatically (it delegates), and
the seam-parity test extends to the video fixture.

## Category + view

`ModelCategory::VIDEO_GENERATION`, appended to `ALL` (media-generation tabs sit
after the text ones):

```ruby
VIDEO_GENERATION = Category.new(
  slug: "video",
  label: "Video generation",
  param: "video",
  path_name: :video_generation,
  sorts: %w[name provider released],
  default_sort: "name",
  default_dir: "asc",
  title: "Video generation API pricing — tokenprice.fyi",
  meta_description: "Video generation model pricing, billed per second of video " \
                    "rather than per token. Native rates and pricing models, " \
                    "updated as providers publish them.",
  matcher: ->(mc) { mc == :video_generation },
  columns: %i[name provider pricing released]
)

ALL = [ LANGUAGE, EMBEDDINGS, SPEECH_TO_TEXT, IMAGE, VIDEO_GENERATION ].freeze
```

Identical shape to `IMAGE` apart from slug/param/path_name/matcher/SEO — the
`:pricing` column, non-price sorts, hidden tier facet (`shows_tier_facet` is
false: no `:tier` column), and `table_colspan` (4 → 6) all fall out of the
shared `columns` data.

Route:

```ruby
get "video-generation", to: "models#index", defaults: { category: "video" }, as: :video_generation
```

- **Controller:** no change. `ModelsController#index` reads sorts/defaults/SEO/
  canonical/columns/counts off `@category`; the modality facet, row filter, and
  etag already ride `@category`.
- **View:** no change. The `:pricing` cell in `index.html.erb` renders video
  rows exactly as image rows (priced / native `price_headline` + badge /
  untracked).
- **Sitemap:** no change. The registry loop emits `/video-generation`
  automatically, and the registry-driven sitemap test already asserts every
  tab's URL is present.
- **Model show page:** no change. The `native_priced?` branch renders
  `price_headline` + `pricing_model_label` + `price_detail` + source; the
  content-for description already handles native-priced rows.

## Data

`docs/VIDEO_MODEL_PRICING.md` — a sourced dataset in the format of
`docs/IMAGE_MODEL_PRICING.md` and `docs/SPEECH_TO_TEXT_MODEL_PRICING.md`: an
as-of header, per-provider tables with a `conf` column, native basis → the
displayed unit, resolution/duration/audio tier notes, and a "Do not publish as
fact" section. Only H/M-confidence rows are seeded.

Roster to research (drop retired, add current notables found):

- **OpenAI** — Sora 2, Sora 2 Pro (per-second, resolution-tiered)
- **Google** — Veo 3.1, Veo 3.1 Fast (per-second, with/without audio) via the
  Gemini API / Vertex
- **Runway** — Gen-4, Gen-4 Turbo (credits → per-second)
- **Kuaishou** — Kling 2.x (per-clip / credits)
- **Pika** — Pika 2.x
- **Luma** — Dream Machine, Ray 2/3 (per-second)
- **MiniMax** — Hailuo
- **Tencent** — Hunyuan Video (open weights)
- **Alibaba** — Wan 2.x (open weights)
- **Lightricks** — LTX / LTXV
- **ByteDance** — Seedance
- **Genmo** — Mochi (open weights)
- **Stability** — Stable Video Diffusion (legacy / open)

Each row: headline native price (per-second where a clean single rate exists,
else per-clip / credits as a `price_summary` string), billing basis, resolution/
duration/audio tiers in `price_detail`, source URL + as-of date, confidence.
Note which are token-billed vs natively per-second, and which are open-weight
(so "self-host $0 / hosted $X" is stated honestly rather than as a single rate).

New providers to add to the seed `providers` map as needed (Kuaishou, MiniMax,
Tencent, Lightricks, Genmo — reuse existing OpenAI/Google/Runway?/ByteDance/
Alibaba/Stability where already present).

## No regressions

- **Estimator / `PriceCatalog.cheapest(tier:)`** requires `input && output`
  (per-token), so video rows (no per-token rate) are excluded — same guard that
  already excludes image and speech-to-text. A test asserts `cheapest` never
  returns the video fixture.
- **OpenRouter sync** is unchanged: video generation is curated-only, like image
  and STT. The `listed` scope already lists a directory class without price
  points.
- **Language tab** excludes video via the unclaimed-fallback matcher (a new
  non-language matcher claims `:video_generation`, so language no longer does).

## Tests (mirror the STT set)

- `modality_class_test`: `[text]→[video]`, `[text,image]→[video]` classify as
  `:video_generation`; `[text,video]→[text]` stays multimodal; label + directory-
  class membership; taxonomy row updates (the two `:other` rows for video output
  become `:video_generation`).
- `ai_model_test`: a `video_gen` fixture is listed, `native_priced?`,
  not `directory_listing?`, `video_generation?`, `price_headline` renders its
  summary; a price-less video fixture is `directory_listing?`.
- `price_catalog_test`: Entry exposes the video row in lockstep;
  `cheapest` never returns it.
- `model_category_test`: `ALL` order, `for("video")`, columns
  (`%i[name provider pricing released]`), `table_colspan` 6, `shows_tier_facet`
  false, SEO copy.
- `models_controller_test`: the video tab lists video rows, swaps in the Pricing
  column, drops per-token headers, hides the tier facet, canonicalizes to
  `/video-generation`, carries video SEO, and excludes video rows from the
  language/image/embeddings/speech tabs.
- `sitemaps_controller_test`: **already covered** by the registry-driven test —
  no new sitemap test needed.
- `test/fixtures/ai_models.yml`: a `video_gen` row (input `[text]`, output
  `[video]`, `pricing_model` + `price_summary`) and optionally a price-less one.

## Ship order

1. **Storage + classification** — the `video_generation` modality rule +
   `DIRECTORY_CLASSES` + labels/description; `video_generation?` and the two
   `PRICING_MODEL_LABELS`; fixtures + tests. (No migration.)
2. **Category + view** — the `VIDEO_GENERATION` `ModelCategory` entry + route +
   SEO. Nothing else to touch (controller/view/sitemap already generic). Tests.
3. **Data** — sourced `docs/VIDEO_MODEL_PRICING.md` research doc + seed roster +
   any new providers. Tests.

Each phase green before the next; then `/code-review --fix`, `/simplify`,
`/verify`, PR, merge on green — the same rhythm as the image, embeddings, and
speech-to-text tabs.
