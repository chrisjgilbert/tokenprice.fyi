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

**Finding (verified against 341 live `/models` rows, mirrors dated to 2026-05-27).**
The classes Phase 3 was meant to price in their native unit — image-gen, TTS,
video — are exactly the ones OpenRouter does **not** price. Dedicated
image-generation rows (FLUX.2, Seedream, Riverflow) carry `{prompt:0, completion:0}`
and no `image`/`request` key; there are no `output:["audio"]` (TTS) rows and **no
`video` pricing key exists at all**. So per-image / per-second native pricing for the
directory classes can't come from OpenRouter — it moves to **Phase 4** (curation /
second source).

What OpenRouter *does* expose are extra cost dimensions on the **text-output models
we already price**. Those are what Phase 3 captures (verified units):

| Dimension | Source key | Unit | Column |
|-----------|------------|------|--------|
| Cache write | `input_cache_write` | per token | `cache_write_per_mtok` |
| Audio input | `audio` | per token | `audio_input_per_mtok` |
| Image input | `image` | per image (flat; provider-dependent — store as quoted) | `image_input_usd` |
| Per-request fee | `request` | flat per request | `request_usd` |

- **Extend `price_points`** with those four as **nullable** columns (the
  `cached_input_per_mtok` precedent — nil = not charged). The text columns
  (`input_per_mtok`/`output_per_mtok`) stay `NOT NULL`, because Phase 3 only enriches
  text-output rows that already have a per-token price — no nullable-text problem.
  Fixed columns over a JSON blob, same reasoning as before. `image_input_usd` is the
  flagged one: OpenRouter's `image` is a per-image surcharge for OpenAI/Anthropic but
  per-token on Google image rows — store the value as quoted and label it "per input
  image"; revisit if the Google edge matters.
- **Wire through** `parse_pricing` (a raw-USD parser alongside `to_mtok` for the
  per-image/per-request values), `record_price` / `same_price?`,
  `PriceCatalog::Snapshot`, the admin form + params, the model page (show a rate only
  when present), and the API (additive — nest the extras under a `pricing` sub-key).
- **Display** the extra dimensions in a secondary "Also billed" block on the model
  page, shown only when present, so the common three-rate row is unchanged.

Deferred (not in Phase 3): `web_search` and `internal_reasoning` (present but nichey),
and all directory-class native pricing (Phase 4).

**Acceptance:** a text/multimodal model round-trips any of the four extra dimensions
sync → catalog → page → API; a change in one of them alone writes a new snapshot;
rows without them are byte-identical to before; suite green.

### Phase 4 — Price the directory classes (curated) · branch `claude/multimodal-curated-pricing`

OpenRouter prices none of the directory classes (image-gen/TTS/video — verified in
the Phase 3 finding), so their native price ("$X / image", "$X / second" the Phase 2
labels promise) has to be **hand-entered**. This is the one phase that finally needs
the nullable-text-rate schema change Phases 2–3 deferred.

**The unit is already class-determined**, so one column carries the value and
`ModalityClass.price_unit` carries the unit — no per-class column sprawl:

- **Schema.** Add `native_price_usd` (decimal 12,6, nullable) to `price_points`, and
  make `input_per_mtok` / `output_per_mtok` **nullable**. A directory model's price
  point sets `native_price_usd` with the two text rates NULL; a text model is
  unchanged (text rates set, `native_price_usd` NULL).
- **Validation.** A price point must price *something*: a custom validation requiring
  either both text rates **or** a native price; text rates stay present-together
  (input without output is invalid). All amounts `>= 0`.
- **`priced?` flips.** Once a directory model has a `native_price_usd` snapshot it's
  `priced?`, so it leaves the "not yet tracked" state automatically — `directory_listing?`
  (price-less + directory class) already encodes this.
- **Display by class.** The model page, index price cell, and API branch on
  `ModalityClass.directory_class?`: a directory-class model shows its native price
  ("$0.04 / image" via `price_unit`) when priced and "not yet tracked" when not —
  **never** the three per-token cards (those would render "—" on NULL text rates).
  Text/multimodal models are byte-identical. `PriceCatalog::Entry` exposes
  `native_price`; the API adds it under `price_per_unit`.
- **Source.** Curated/admin only — the sync is untouched (OpenRouter has no data
  here). The admin price form shows a "Native price" field (with the class's unit
  label) for directory-class models.
- **Data.** Seed a few well-known real examples (a couple of image-gen models at
  their real per-image price) so the feature ships non-empty and demonstrable; the
  rest is ongoing curation.

Acceptance: a curated image-gen model shows "$X / image" end to end (page, index,
API) and drops out of "not yet tracked"; text rows are byte-identical; a price point
with neither text rates nor a native price is invalid; suite green.

---

## Dependency graph & order

```
Phase 1 (signature + classify + filter)  ── ships alone; answers text-only vs multimodal
        │
Phase 2 (admit non-text-output models)   ── unlocks image-gen / TTS / STT / video filters
        │
Phase 3 (extra price dimensions)         ── captures cache-write/image/audio/request on text models
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

## Resolved before Phase 3 (verified against live `/models` mirrors)

- **Units.** `audio` is per **token** (not per second), `input_cache_write` per
  token, `request` flat per request, `image` per image (provider-dependent). No
  `video` key exists. Image-gen/TTS/video models carry no usable price in `/models`
  — see the Phase 3 finding. Columns named accordingly.
- **API contract.** The four extra dimensions nest under the existing model's
  `pricing` object additively; existing `price_per_mtok` keys are untouched.

## Green gate

Every phase ends on the `preflight` skill (RuboCop, Brakeman, bundler-audit,
importmap audit, full test suite, seed replant) before push, per `CLAUDE.md`.
Credential-touching tests stub with `stub_anthropic_key!` / `stub_admin_digest!`.
