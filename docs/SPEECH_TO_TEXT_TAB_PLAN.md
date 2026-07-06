# Speech-to-text (transcription) tab — spec

> **Status:** Proposed. The fourth pricing category, after language, image, and
> embeddings. Read `docs/EMBEDDINGS_TAB_PLAN.md` and the tabs work (PR #114/#115)
> first; the `ModelCategory` column-as-data model and the image native-price
> pattern are the two things this builds on.

## Why STT next

Transcription is the cleanest of the remaining categories: a single homogeneous
unit (**USD per minute of audio**), abundant first-party pricing, and a large,
price-sensitive developer audience that genuinely shops on $/min. It also
introduces the per-minute-audio unit that makes TTS and realtime voice easy
follow-ons.

Unlike image (heterogeneous units — per-image, per-MP, credits), STT's single
unit means people will want to **sort by cheapest $/min**. That drives the one
new piece of infrastructure below.

## 1. Classification — a new `speech_to_text` modality class (the wrinkle)

A pure transcription model is audio in → text out. Today `ModalityClass` maps
that to **`multimodal`** (`nontext_input? && text_output?`, modality_class.rb:101),
so it would fall into the language tab. We need a dedicated class that also
distinguishes a *transcription* model from an audio-*capable chat* model (which
takes `[text, audio]` in and belongs in language as multimodal).

Add to `app/models/modality_class.rb`:
- A `SIGNATURE_RULES` entry **before `multimodal`**:
  `speech_to_text: -> { @input == %w[audio] && text_output? }` — audio-ONLY input,
  text output. A chat model with `[text, audio]` input still matches `multimodal`.
- `LABELS[:speech_to_text] = "Speech to text"`; `DESCRIPTIONS[:speech_to_text] =
  "Audio in, a text transcript out."`
- Add `:speech_to_text` to `DIRECTORY_CLASSES` — STT models have no per-token
  price point, so they list via the modality_class column (like image). Language's
  `!directory_class?` fallback then excludes them automatically, and the new
  category claims `:speech_to_text` — the membership refactor needs no other edit.

`test/models/modality_class_test.rb`: assert `[audio]→[text]` is `speech_to_text`;
`[text,audio]→[text]` stays `multimodal`; `speech_to_text` is a directory class.

## 2. Storage — a sortable numeric native price (the one new mechanism)

Image stores a `price_summary` **string** because its units don't share a scale.
STT does share one, so a string cell can't be sorted. Add a numeric native price:

- **Migration:** `add_column :ai_models, :native_price_usd, :decimal, precision: 12,
  scale: 6` and `:native_price_unit, :string` (e.g. `"/min"`). Nullable; only
  single-unit native categories (STT now; TTS later) set them.
- This is **additive to**, not a replacement for, `price_summary`: image keeps its
  heterogeneous string; STT uses the numeric pair so its Price column sorts. A
  category's Price *column key* decides which it reads (see §3).
- `AiModel`: extend `native_priced?` to `price_summary.present? || native_price_usd.present?`;
  keep `directory_listing?` as "no price of any kind" (`current_price.nil? &&
  !native_priced?`). **`PriceCatalog::Entry` must be updated in lockstep** — it has
  its own `native_priced?`/`directory_listing?` and would otherwise disagree (the
  seam-parity test already guards this); expose `native_price_usd`/`native_price_unit`
  on the Entry too.
- **One display source of truth.** Add `AiModel#price_headline` returning the
  formatted native price — `"#{usd_plain(native_price_usd)} #{native_price_unit}"`
  when the numeric is set, else `price_summary`. The index native-price cell and
  the model-page native card both read `price_headline`, so the number lives in
  one place (native_price_usd) and image's string path is unchanged.
- **Sort:** add a `"native_price"` lambda to `ModelsController::SORTS`
  (`->(m){ m.native_price_usd || Float::INFINITY }`) so a price-less row sinks on
  asc. Every *listed* STT row has a price (no price → not listed), so the
  reverse-float edge the token `PRICE_SORTS` sink guards against can't bite here;
  leave `native_price` out of `PRICE_SORTS` for v1 and revisit only if a price-less
  native row can ever list.
- **No estimator/guide regression:** STT rows have neither `input` nor `output`
  (no price point), so `PriceCatalog.cheapest` (which now requires both) already
  excludes them — the same guard the embeddings work added. Confirm with a test.
- Native-price **history** stays out of scope (image is current-only too); note it
  as a future extension if native categories ever need trend charts.

## 3. ModelCategory + columns

Add a `SPEECH_TO_TEXT` entry:
- slug `"speech-to-text"`, label `"Speech to text"`, param, `path_name: :speech_to_text`
- route `get "speech-to-text", to: "models#index", defaults: { category: "speech_to_text" }, as: :speech_to_text`
- `matcher: ->(mc){ mc == :speech_to_text }`
- `columns: %i[name provider native_price released]`
- `sorts: %w[native_price name provider released]`, `default_sort: "native_price"`,
  `default_dir: "asc"` (cheapest per minute first)
- title/meta in the copy style (e.g. "Speech-to-text API prices, per model —
  tokenprice.fyi"; meta names the fact: transcription billed per minute of audio).

The view already iterates `@category.columns`. Add one column key:
- `:native_price` → a sortable numeric Price cell: `usd(model.native_price_usd)` +
  `native_price_unit`, with the `tp-col-highlight` on the active sort. This is a
  *third* price-cell shape alongside the token cells (`:input` etc.) and image's
  string `:pricing` cell — all live in the same per-key `case`.

`ALL` order: language, embeddings, speech-to-text, image (put the token-comparable
tabs first, the native ones after — or group by "understanding vs generation"; a
copy call, not load-bearing).

## 4. No sync change

OpenRouter carries token-priced chat models, not per-minute transcription
endpoints (Deepgram/AssemblyAI/etc. aren't on it). STT is **curated/seeded only**,
like image — the sync stays untouched. (A multimodal audio *chat* model keeps
classifying as `multimodal` → language, correctly.)

## 5. Data (sourced pass before seeding, like the others)

Seed the well-known transcription models with real **$/min** + sources, H/M
confidence only. Candidates (verify each on the provider's page at build time):
- **OpenAI**: Whisper (`whisper-1`, ~$0.006/min), `gpt-4o-transcribe` /
  `gpt-4o-mini-transcribe` (note: these are token-billed, so compute a per-min
  equivalent or flag the unit — a mini version of image's token-based case).
- **Deepgram**: Nova-3 / Nova-2 (~$0.0043/min pay-as-you-go).
- **AssemblyAI**: Universal / Nano (tiered ~$0.006–$0.012/min).
- **Google** Cloud STT, **Azure** Speech, **Speechmatics**, **Gladia**, **Rev AI**,
  **Groq** (`whisper-large-v3`, per-hour → per-min), **ElevenLabs** Scribe.
- New providers to add: Deepgram, AssemblyAI, Speechmatics, Gladia, Rev AI (+ any
  of Groq/ElevenLabs not already present).
- **Tier caveat:** batch vs streaming, and nano/best tiers, differ. Pick the
  standard/pay-as-you-go per-minute rate as the sortable `native_price_usd`, name
  the tier in a `price_detail` sentence, and put anything unconfirmed in a
  "do not publish" list — mirror `docs/IMAGE_MODEL_PRICING.md`.

## 6. Model page

An STT model is `native_priced?` (via `native_price_usd`) but not `priced?` (no
price point). Reuse the native-price card the model page already renders for image
directory rows, showing `$X / min` + `price_detail` + source + as-of. No per-token
cards.

## 7. Tests

- ModalityClass: the new rule + ordering + directory-class membership.
- AiModel/PriceCatalog: `native_priced?` true via `native_price_usd`; a
  native-priced STT row is `listed`, not a `directory_listing?`; the numeric sort.
- Controller/view: `/speech-to-text` lists STT models with a Price column that
  sorts by $/min (default asc); language/embeddings/image exclude STT; three→four
  tab strip with counts; canonical + per-tab SEO; sitemap includes the path.
- Seeds/fixtures: an STT fixture (`native_price_usd`, `native_price_unit "/min"`,
  modality_class `speech_to_text`, input `[audio]`, output `[text]`).

## 8. Decisions (settled)

1. **Numeric `native_price_usd` + `native_price_unit`** — STT's Price column is a
   real sortable $/min number (not image's string-only cell). This is the one new
   mechanism; it generalizes to TTS and any future single-unit category.
2. **Token-billed transcription models** (e.g. `gpt-4o-transcribe`) are seeded with
   a **computed per-minute equivalent** at a stated audio assumption, sourced and
   noted in `price_detail` — comparable in the same $/min column, not left
   price-less.
3. Tab label **"Speech to text"**; strip order **language · embeddings ·
   speech-to-text · image** (token-comparable tabs first, native ones after).

## 9. Ship order (sub-agent TDD, established rhythm)

1. **Storage + classification** — migration (`native_price_usd`/`native_price_unit`),
   the `speech_to_text` ModalityClass rule + DIRECTORY_CLASSES, `native_priced?`
   extension, the `native_price` sort, a fixture. Tests.
2. **Category + view** — `SPEECH_TO_TEXT` ModelCategory (+ the `:native_price`
   sortable column), route, sitemap, the price cell. Tests.
3. **Data** — sourced $/min research doc + seed roster + providers. Tests.

Each phase green before the next; then `/code-review --fix`, `/simplify`,
`/verify`, PR, merge on green. Prices get a sourced verification pass before
seeding — no publishing $/min from memory.
