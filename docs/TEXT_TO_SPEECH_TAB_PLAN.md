# Text-to-speech category tab — plan

> The sixth pricing-table category, grouped with speech-to-text as the audio
> pair. Text-to-speech is **speech-to-text-shaped**: TTS bills predominantly
> **per character** of input text, which normalizes to a single comparable,
> sortable unit — **USD per 1M characters** — exactly as speech-to-text
> normalizes everything to $/min. So it reuses STT's numeric `native_price_usd`
> storage, the sortable `native_price` column, the `native_price` sort +
> `SINK_SORTS` entry, and the `price_headline` display, with almost no new code.
> Companion to `docs/SPEECH_TO_TEXT_TAB_PLAN.md`.

## Why it's near-free (STT-shaped, not video-shaped)

Video generation was heterogeneous (per second / clip / credits / tokens) → it
reused image's `price_summary` strings. Text-to-speech is the opposite: OpenAI,
Google, Azure, Amazon, Deepgram, Cartesia, PlayHT, Rime all bill **per
character** (quoted per 1K or per 1M chars). Normalized to **$/1M chars**, the
column is genuinely comparable and sortable — the STT pattern fits exactly.

Reused unchanged from the speech-to-text work:
- `native_price_usd` (decimal) + `native_price_unit` storage — no migration.
- The `:native_price` sortable column cell in `index.html.erb` (renders
  `price_headline`; header is the generic "Price", so `$15.00 /1M chars` and
  `$0.006 /min` both read correctly).
- The `native_price` `SORTS` lambda and the `SINK_SORTS[native_price] =>
  :native_priced?` sink, so an unpriced TTS row sinks rather than floating on a
  reversed sort.
- `price_headline`, `native_priced?`, `directory_listing?`, the model-page
  native card, the registry-driven sitemap.

New code is only: a modality rule, label/description, `DIRECTORY_CLASSES` entry,
a `text_to_speech?` predicate, a `ModelCategory` entry, a route, SEO, and seeds.

## The unit decision (and the honest outlier handling)

**Headline unit: USD per 1M characters** (`native_price_unit: "/1M chars"`).
Per-1K-char quotes convert ×1000; per-character quotes ×1,000,000.

Not every TTS model is per-character. Two honest fallbacks, matching how STT
handled OpenAI's token-billed transcribe models:
- **Credit-based** (ElevenLabs): credits ≈ characters, so state the credit→char
  basis and seed the effective $/1M chars at the cheapest paid PAYG tier, noted
  in `price_detail`.
- **Token-based** (OpenAI `gpt-4o-mini-tts`, if applicable): seed a per-1M-char
  equivalent at a stated assumption, flagged in `price_detail` as an estimate.
- **Per-minute-of-audio only**: if a model is genuinely priced only per minute of
  output audio and no per-char rate exists, leave `native_price_usd` unset and
  carry a `price_detail` note (directory_listing "not yet tracked"), rather than
  fabricate a char rate. Same honest-untracked pattern as Luma Ray3.14.

Voice-quality tiers (Standard vs Neural/WaveNet/Studio/HD/Chirp3-HD; ElevenLabs
Flash vs Multilingual) are handled like STT's batch/stream: the headline is the
standard neural tier's rate, other tiers noted in `price_detail`.

## Classification

`ModalityClass` gains a `text_to_speech` rule, the mirror of `speech_to_text`:

```ruby
# in SIGNATURE_RULES, right after speech_to_text (keeps the audio pair adjacent):
speech_to_text:   -> { @input == %w[audio] && text_output? },
text_to_speech:   -> { @input == %w[text] && @output == %w[audio] },
```

- `[text] → [audio]` → **text_to_speech**. Classifies as `:other` today, so this
  is a pure widening.
- Narrow like STT: text-**only** input. `[text, audio] → [audio]` (voice
  conversion / speech-to-speech) does **not** match — it isn't TTS — and falls
  through to `:other`, deliberately.
- Symmetry: audio **out** from text = synthesis; audio **in** to text =
  transcription (STT); audio **in and out** = something else (`:other`).
- Ordering is safe: `multimodal` needs `nontext_input?`, which text-only input
  fails, so `text_to_speech` can't be shadowed regardless of position.

Also: `LABELS[:text_to_speech] = "Text to speech"`,
`DESCRIPTIONS[:text_to_speech] = "Text in, generated speech (audio) out."`,
`DIRECTORY_CLASSES += :text_to_speech`.

## Storage

**None** (no migration). Reuses `native_price_usd` + `native_price_unit` with the
unit string `"/1M chars"`. `AiModel#text_to_speech? = modality_class ==
:text_to_speech`.

## Category + view

`ModelCategory::TEXT_TO_SPEECH`, inserted **after `SPEECH_TO_TEXT`** in `ALL` so
the tab strip groups the audio pair (STT · TTS) before the visual pair
(image · video):

```ruby
TEXT_TO_SPEECH = Category.new(
  slug: "text-to-speech",
  label: "Text to speech",
  param: "text-to-speech",
  path_name: :text_to_speech,
  sorts: %w[native_price name provider released],
  default_sort: "native_price",
  default_dir: "asc",
  title: "Text-to-speech API pricing, per model — tokenprice.fyi",
  meta_description: "Text-to-speech (speech synthesis) model pricing, billed per 1M characters " \
                    "of input text. Native per-character rates across providers, updated as they publish them.",
  matcher: ->(mc) { mc == :text_to_speech },
  columns: %i[name provider native_price released]
)

ALL = [ LANGUAGE, EMBEDDINGS, SPEECH_TO_TEXT, TEXT_TO_SPEECH, IMAGE, VIDEO_GENERATION ].freeze
```

Same column set / sorts / default as `SPEECH_TO_TEXT`. Route:

```ruby
get "text-to-speech", to: "models#index", defaults: { category: "text-to-speech" }, as: :text_to_speech
```

Controller, view, sitemap, and show page need **no change** — the sortable
native-price column, the sink, the model-page native card, and the sitemap loop
already handle it.

## Data

`docs/TEXT_TO_SPEECH_MODEL_PRICING.md` — sourced dataset in the STT doc's format,
normalized to **$/1M chars**, H/M confidence only. Roster: OpenAI (tts-1,
tts-1-hd, gpt-4o-mini-tts), ElevenLabs (Flash v2.5, Multilingual v2), Google
(Neural2, WaveNet, Studio, Chirp3-HD), Azure (Neural, HD), Amazon Polly
(Standard, Neural, Generative), Deepgram (Aura-2), Cartesia (Sonic), PlayHT,
Rime. New providers to add as needed (cartesia, playht, rime, hume);
openai/google/microsoft/amazon/deepgram/elevenlabs already exist.

## No regressions

- `PriceCatalog.cheapest(tier:)` requires `input && output`, so TTS rows are
  excluded (same guard as STT/image/video). A test asserts it.
- OpenRouter sync unchanged (TTS is curated-only).
- Language tab excludes TTS via the matcher.

## Tests (mirror STT)

modality_class (text→audio → text_to_speech; [text,audio]→[audio] stays other;
label + directory-class), ai_model (a tts fixture: listed, native_priced?,
text_to_speech?, price_headline "$15.00 /1M chars"), price_catalog (Entry +
seam-parity + cheapest excludes), model_category (ALL order, columns, sorts,
default native_price, SEO), models_controller (tab lists rows, Price column,
sortable, hides tier facet, canonical/SEO, excluded from other tabs). Sitemap is
auto-covered by the registry-driven test.

## Ship order

1. **Storage + classification + category** — modality rule + predicate + labels +
   `DIRECTORY_CLASSES`; the `TEXT_TO_SPEECH` `ModelCategory` + route; fixtures +
   tests. (Classification and category land together — a new directory class
   with no category leaks onto the language tab.)
2. **Data** — sourced `docs/TEXT_TO_SPEECH_MODEL_PRICING.md` + seed roster + any
   new providers. Tests.

Then `/code-review --fix`, `/verify`, PR, merge on green.
