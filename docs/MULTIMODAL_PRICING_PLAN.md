# Multimodal plan — classify models by what they turn into what

Companion to the **Architecture** section of `CLAUDE.md`. This is a work-breakdown
for teaching the catalogue to record each model's **modality signature** — the set
of inputs it accepts and outputs it produces — and to let people find models by it.

Read the **Architecture** and **Copy style** sections of `CLAUDE.md` first. This
file is the *what* and the *order*.

> **Status:** Proposed. Nothing here is built yet.

---

## The jobs to be done

A visitor wants to filter the catalogue by what a model actually does:

- which models are **text only** (text in, text out)
- which are **multimodal input** (text + image and/or audio in, text out)
- which are **text-to-speech** (text in, audio out)
- which are **speech-to-text** (audio in, text out)
- which are **image generation** (text, sometimes + image, in; image out)
- which are **image editing** (image + text in, image out)
- which are **video generation** (text or image in, video out)
- which produce **embeddings** (text or image in, vector out)
- which are **realtime voice** (audio in, audio out)
- which are **rerankers** (query + documents in, relevance scores out)

Every one of these is a question about a model's **(input modalities → output
modalities)** signature — except reranking, which is defined by its task rather than
its media types (see the taxonomy note below). So the signature is the thing to record, and a derived
**class** label is the thing to filter on.

---

## What this changes about the current design

The catalogue today records only text-token pricing and, critically, **only admits
text-output models**. `OpenRouter::ModelSync#text_output?`
(`app/models/open_router/model_sync.rb:249`) skips any row whose
`architecture.output_modalities` doesn't include `text` — so image-generation,
text-to-speech, embedding, and video models never enter the catalogue at all.
That gate is the single biggest blocker to the jobs above: you can't answer "which
models are image generation" while filtering image-generation models out at
ingestion.

So this plan does two things the previous draft didn't:

1. **Records a full modality signature** for every model, not just a "reads images"
   badge on text models.
2. **Admits non-text-output models** into the catalogue, classified — replacing the
   binary `text_output?` gate with a recorded signature plus per-class handling.

The pricing work from the earlier draft still matters, but it's downstream of
classification, and it has to reckon with the fact that **different classes price in
different units** (see Phase 3).

---

## The modality signature and the derived class

Two recorded facts per model:

- `input_modalities` — sorted string set, e.g. `["image", "text"]`
- `output_modalities` — sorted string set, e.g. `["text"]`

Modality vocabulary (closed set, normalised lowercase): `text`, `image`, `audio`,
`video`, `file`, `embedding`. Anything OpenRouter sends outside this maps to the
nearest term or is dropped, logged once.

From the signature we derive a single **`modality_class`** for the JTBD filters. The
derivation is deterministic and lives in one place (a `ModalityClass` value object,
`app/models/modality_class.rb`), so the rules are reviewable and testable. Class
names follow the input→output naming you'd filter on (`text_to_audio`, not "TTS"):

| Class | Rule (input → output) | Examples |
|-------|-----------------------|----------|
| `text` | `{text}` → `{text}` | most chat LLMs |
| `multimodal` | input ⊃ `{text}` plus image/audio/video/file → `{text}` | GPT-4o, Gemini 2.5 (incl. video *understanding*) |
| `text_to_audio` | `{text}` → `{audio}` | TTS, music generation |
| `audio_to_text` | `{audio}` (± text) → `{text}` | Whisper-class, transcription, speech translation |
| `speech_to_speech` | `{audio}` → `{audio}` | realtime voice / voice agents |
| `image_generation` | text (± image) → `{image}` | Imagen, DALL·E-class |
| `image_editing` | `{image, text}` → `{image}` | inpaint / edit models |
| `video_generation` | text or image → `{video}` | Veo / Sora-class |
| `embedding` | text or image → `{embedding}` | embedding models (incl. multimodal embeddings) |
| `rerank` | text query + documents → relevance scores | Cohere / Voyage / Jina rerankers |
| `any_to_any` | mixed inputs → multiple outputs incl. non-text | omni / native-multimodal output models |
| `other` | anything unmatched | moderation, 3D, etc. — logged for triage |

**Two classes aren't pure media signatures.** `rerank` and moderation-style models
take text and return *scores or labels*, not a media modality — so their "output"
doesn't appear in `output_modalities`. The classifier identifies these from
OpenRouter's endpoint/category hint (e.g. a rerank endpoint), not from the signature
alone. Everything else is signature-derived. This is the one seam where a model's
*task* matters beyond its modalities; keep it isolated in `ModalityClass` so the rest
of the system only ever sees the resolved class.

`modality_class` is **derived, not stored** as truth — compute it from the signature
(plus the endpoint hint for the two task classes) so a re-classification is a code
change, not a backfill. Cache it on the row only if the index query needs it for
sorting; otherwise derive on read.

---

## Where the assumption lives today

| Layer | File | What's hardcoded |
|-------|------|------------------|
| Ingestion gate | `open_router/model_sync.rb:249`–`252` | non-text-output rows skipped entirely |
| Schema | `db/schema.rb:14`–`37` | `ai_models` has no modality columns |
| Schema | `db/schema.rb:73`–`85` | `price_points` has three per-token rate columns only |
| Read model | `app/models/price_catalog.rb:12` | `Snapshot` carries input/output/cached only |
| Surface | models/providers controllers + views, `api/v1/models_controller.rb:18` | no modality field, no class filter |

---

## The phasing

Four phases, JTBD-ordered. Each is independently shippable and revertible. Phases 1
and 2 deliver the filters the jobs above ask for; Phase 3 prices the new classes;
Phase 4 fills coverage gaps the data source leaves.

### Phase 1 — Record the signature, classify, filter · branch `claude/multimodal-signature`

Answers "text-only vs multimodal-input" immediately, within the models already in
the catalogue.

- **Migration.** Add to `ai_models`: `input_modalities`, `output_modalities` as
  `t.json` (default `[]`).
- **Sync.** In `enrich` (`model_sync.rb:338`), read
  `architecture.input_modalities` / `output_modalities`, normalise to the closed
  vocabulary, assign — under the existing augment-don't-clobber rule (overwrite rows
  we own, fill only blanks on curated/linked rows).
- **Classify.** `ModalityClass` value object with the derivation table above;
  `AiModel#modality_class`, `#multimodal?`, modality readers.
- **Surface.**
  - Models index: a **class filter** (facet by `modality_class`) and a per-row badge.
    This is the deliverable the jobs name. Copy style: name the fact ("Image
    generation", "Speech-to-text"), not a marketing label.
  - Model page: show the signature ("Text, image in → text out").
  - Public API: additive `modalities` + `modality_class` keys.
- **Tests / fixtures.** Extend `or_model` with `input_modalities:`; fixtures across
  several classes; assert derivation and the filter.

**Acceptance:** existing text and multimodal-input rows classify correctly; the
index filters by class; text-only rows look unchanged; suite green.

### Phase 2 — Admit non-text-output models · branch `claude/multimodal-admit`

This is the scope expansion that unlocks "image generation", "text-to-speech",
"video generation". **The pivotal product decision in this whole plan.**

- **Replace the gate.** `text_output?` (`model_sync.rb:249`) stops being a skip
  condition. Instead, record the signature for every priced row and let
  `modality_class` carry the distinction. Keep skipping only genuinely un-priceable
  rows (the existing `parse_pricing` nil guard) — not whole classes.
- **Reckon with the pricing table.** `price_points` assumes per-token rates, which
  don't describe an image-gen or TTS model. Two honest options for v1:
  - **(a) Directory-first.** Admit non-text-output models as catalogue entries with
    a signature and class, but mark their pricing "priced per image / per second —
    not yet tracked" until Phase 3. Delivers every filter immediately; defers the
    money.
  - **(b) Gate Phase 2 on Phase 3.** Don't admit a class until its pricing unit
    exists, so no entry ever shows a blank or misleading price.

  **Recommend (a):** the jobs are discovery jobs ("which models *are* X"), and a
  directory that lists image-gen models without a per-image price is still useful
  and honest, as long as the missing price is labelled, not faked. Pricing follows
  in Phase 3.
- **Guard the headline surfaces.** The cheapest-frontier headline, the sort sets,
  and the guide read per-token prices — make sure a newly-admitted image-gen model
  with no per-token price can't crash or pollute them (it has no `input_per_mtok`).
  Scope those reads to text/multimodal classes explicitly.

**Acceptance:** image-generation and other non-text-output models appear, correctly
classed and filterable; none corrupts the text-pricing headline, sorts, or guide;
their price reads as "not yet tracked", not `$0`.

### Phase 3 — Per-class pricing · branch `claude/multimodal-pricing`

Different classes bill in different units, so this isn't one schema:

| Class | Native unit | OpenRouter field |
|-------|-------------|------------------|
| `text`, `multimodal` | per token | `prompt`, `completion`, `input_cache_read`, `input_cache_write` |
| `image_generation`, `image_editing` | per image (± by size/quality tier) | `pricing.image` (output) |
| `text_to_audio` | per character or per second of audio | `pricing.audio` |
| `audio_to_text`, `speech_to_speech` | per minute/second of audio | `pricing.audio` |
| `video_generation` | per second of video | (often absent — see Phase 4) |
| `embedding` | per input token | `prompt` |
| `rerank` | per search/query unit | `request` (or a rerank-specific field) |

- **Verify units against live rows before naming any column.** Audio is per-token
  for some providers, per-second for others; image is per-image for the OpenAI/Google
  rows but confirm. Name columns for the unit that's actually quoted.
- **Extend `price_points`** with the well-known dimensions as nullable columns
  (mirroring the `cached_input_per_mtok` precedent — nil means "not charged / not
  applicable"): `cache_write_per_mtok`, `image_output_usd`, `request_usd`, plus the
  verified audio unit. Fixed columns over a JSON blob — same reasoning as before:
  validatable, sortable, in-style with the append-only `PricePoint`.
- **Wire through** `parse_pricing` / `record_price` / `same_price?`,
  `PriceCatalog::Snapshot`, the admin form + params, the model page (show a rate only
  when present), and the API (additive).
- **Show class-appropriate prices.** An image-gen row shows "$X / image"; a TTS row
  "$X / 1M characters" — the model page renders by class, not one fixed three-column
  table.

**Acceptance:** a model in each priced class round-trips its native-unit price
sync → catalog → page → API; a non-text reprice writes a snapshot; text rows are
byte-identical to before; suite green.

### Phase 4 — Coverage beyond OpenRouter · branch `claude/multimodal-coverage` (future)

OpenRouter lists mostly chat/text models and a growing set of image models.
Text-to-speech, speech-to-text, and especially **video generation** are thinly
covered or absent there. So some JTBD classes will show few or zero entries on
OpenRouter data alone.

- Flag per-class coverage honestly in the UI ("3 video-generation models tracked")
  rather than implying the list is exhaustive.
- Add curated/manual rows or a second source for the under-covered classes. The
  `source == "manual"` path and admin UI already support hand-curated entries; this
  is mostly data entry plus a per-class price form from Phase 3.

This phase is data, not architecture. Sequence it last, or treat it as ongoing
curation once Phases 1–3 establish the shape.

---

## Dependency graph & order

```
Phase 1 (signature + classify + filter)  ── ships alone; answers text-only vs multimodal
        │
Phase 2 (admit non-text-output models)   ── unlocks image-gen / TTS / STT / video filters
        │
Phase 3 (per-class pricing)              ── prices the admitted classes in native units
        │
Phase 4 (coverage)                       ── data/curation for classes OpenRouter misses
```

One phase per PR — small, reviewable, independently revertible. Phase 1 is pure
addition (no behaviour change to existing rows). Phase 2 is the one with real product
risk: it changes *which models exist* in the catalogue, so review it on its own.

## Decisions (settled)

1. **Scope of admission (Phase 2).** All classes in the taxonomy table are in for
   v1, **including embeddings and rerank**. The catalogue becomes a directory of
   every priced model OpenRouter lists, classified — not just text-output models.
2. **Directory-first (Phase 2 (a)).** Admit non-text-output models with their class
   and signature before per-class pricing lands; label the missing price ("priced
   per image — not yet tracked"), never fake it as `$0`. Pricing follows in Phase 3.

## Still to verify before Phase 3 (data questions, not design)

- **Units.** Confirm audio (`pricing.audio`) and image (`pricing.image`) units
  against live OpenRouter rows before naming columns — audio is per-token for some
  providers, per-second for others.
- **API contract.** Whether non-text rates nest under a `pricing_by_class` key or
  flatten alongside `input`/`output`. Additive either way; pick before publishing.
  Default: nest under `pricing_by_class` so the shape scales with the taxonomy.

## Green gate

Every phase ends on the `preflight` skill (RuboCop, Brakeman, bundler-audit,
importmap audit, full test suite, seed replant) before push, per `CLAUDE.md`.
Credential-touching tests stub with `stub_anthropic_key!` / `stub_admin_digest!`.
