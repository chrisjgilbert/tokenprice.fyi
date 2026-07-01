# Image-generation category — directory-first plan

> **Status:** Proposed (2026-07). A scoped, single-category revival of the
> `docs/MULTIMODAL_PRICING_PLAN.md` directory-classes that were removed in
> 2026-06. Read that file and the **Architecture** + **Copy style** sections of
> `CLAUDE.md` first. This plan does *one* class — image generation — directory-first
> (list + filter, price labelled "not yet tracked"), so we can validate the shape
> before reviving TTS / STT / video.

## Why now

Today the catalogue "tracks token-priced models only": the OpenRouter sync skips
any model that doesn't output text (`model_sync.rb:194`), and `ModalityClass`
collapses every non-text-output signature to `:other`
(`app/models/modality_class.rb:12`). Two consequences:

- Pure image-generation models (FLUX, Seedream, Imagen, DALL·E-class) never enter
  the catalogue.
- A model that outputs *both* image and text — Gemini's image model, "nano
  banana" — slips *past* the text-output gate, gets priced per-token like a chat
  model, and lands in the main table tagged only "Omnimodal". It's mixed in with
  chat LLMs, which is the confusion this plan removes.

Goal: an **Image generation** category people can filter to and compare within,
with honest pricing (the real per-token price where one exists, "not yet tracked"
otherwise — never a faked `$0`).

## Design decisions (settled for this cut)

1. **Extend `modality_class`, don't add a parallel `category` column.**
   `modality_class` is already the one "what does this model do" filter axis
   (column, index, facet, badge, API key). A second concept would be two things
   meaning the same thing. We revive `image_generation` as a class.
2. **`image_generation` = "output includes `image`", ordered *before* `any_to_any`.**
   A model that emits an image is doing image generation in the visitor's mental
   model, whether or not it also emits text. Ordering the rule before `any_to_any`
   reclassifies nano banana (image **+** text out) into `image_generation` —
   directly fixing the reported confusion. Image *editing* folds into this class
   for v1 (split later if it earns its keep).
3. **Directory-first, no fabricated prices.** Image-gen rows are admitted without
   a price point when OpenRouter carries no usable price (FLUX et al. quote
   `{prompt:0, completion:0}`). Their price cell reads "Not yet tracked". A model
   that *does* carry a real price (nano banana is per-token on Google) keeps
   showing it — honest, not removed. Per-image curated pricing is a later phase.
4. **Keep the headline surfaces text-only.** The cheapest-frontier headline,
   price sorts, guide, and estimator read per-token rates; a price-less image-gen
   row must never crash or pollute them. Existing nil-guards already cover most of
   this (`SORTS` use `|| Float::INFINITY`; `PriceCatalog.cheapest` filters
   `e.input`); we verify and add tests rather than assume.

## The changes, by seam

### 1. Taxonomy — `app/models/modality_class.rb`

- Add `image_generation` to `LABELS` ("Image generation") and `DESCRIPTIONS`
  ("Text (and optionally an image) in, an image out.").
- Add a `SIGNATURE_RULES` entry **before** `any_to_any`:
  `image_generation: -> { @output.include?("image") }`.
- Update the class-level doc comment: the taxonomy no longer stops at
  token-priced classes — `image_generation` is a priced-later directory class.
- Add `DIRECTORY_CLASSES = %i[image_generation].freeze` and a
  `ModalityClass.directory_class?(symbol)` predicate — the one place that knows
  which classes are listed-without-a-token-price. (Grows as TTS/STT return.)

`test/models/modality_class_test.rb`: assert `{text}→{image}`,
`{image,text}→{image}`, and `{text}→{image,text}` (nano banana) all classify as
`image_generation`, and that it wins over `any_to_any`.

### 2. Admit image-gen rows — `app/models/open_router/model_sync.rb`

The current `import` (`model_sync.rb:178`) returns `:skipped` when
`parse_pricing` is nil (line 180) *and* when output isn't text (line 195). Both
gates exclude image-gen. Restructure so a **directory-class** row is admitted
without a price:

- Compute the signature early (build the model, `enrich`, then read
  `model.modality_class`).
- If `parse_pricing` is nil **but** `ModalityClass.directory_class?(model.modality_class)`,
  admit the row: save it (with editorial generation as today) and **do not** call
  `record_price`. Return `:created` / `:enriched` accordingly. Add a
  `Result` counter or reuse `:enriched` — TBD, small.
- Keep the existing skip for a nil-priced row that is *not* a directory class
  (genuinely un-priceable text/other rows stay out).
- The `outputs_text` guard (line 194) stops gating admission; it still gates
  whether we *write a per-token price* (a directory-class row that happens to
  carry token pricing — nano banana — still records it).

Note the augment-don't-clobber rule holds: `enrich` already guards modality
writes behind `.present?` so an omitted `architecture` can't wipe a signature.

### 3. List price-less directory rows — `app/models/ai_model.rb`

`listed` (`ai_model.rb:44`) currently requires a price point. Widen it:

```ruby
scope :listed, -> {
  where.not(status: "retired")
    .where("ai_models.id IN (SELECT ai_model_id FROM price_points)" \
           " OR ai_models.modality_class IN (?)", ModalityClass::DIRECTORY_CLASSES.map(&:to_s))
}
```

Add predicates:
- `directory_listing?` — `ModalityClass.directory_class?(modality_class) && current_price.nil?`
  (listed, but priced-per-image-not-yet-tracked).
- `token_priced?` already returns false without an input rate, so price sorts sink
  these rows correctly in both directions — no sort change needed.

### 4. Price display — views + `PriceCatalog`

- `PriceCatalog::Entry` already tolerates a nil `current` (all price accessors are
  `current&.…`). Add `directory_listing?` mirroring the model, so the view branches
  off the catalog entry, not an AiModel.
- **Models index price cells** (`app/views/models/index.html.erb`, the Input/Output/
  Cached `<td>`s near the row at line 634): when `model.current_price.nil?`, render a
  single "Not yet tracked" cell instead of three "—" rates. The `modality_badge`
  (already at line 634) shows the "Image generation" pill with no change.
- **Model page** (`models#show` view): show the signature line ("Text in → image
  out") and, for a `directory_listing?` model, a "Priced per image — not yet
  tracked" note in place of the per-token price block. The existing `@catalog_entry`
  is nil for price-less rows (`PriceCatalog.model` only returns listed *priced*
  rows) — it now returns the directory entry too, so guard the extra-billing block
  on `entry.current.present?`.
- **Facet copy:** the filter is titled "Modality" (`index.html.erb:491`). Optionally
  relabel to "Category" to match how people think ("image generation" is a category,
  not a modality). Low-risk copy change; call it out for review. The
  `image_generation` pill appears automatically once such rows are `listed`
  (`@modality_classes` is derived from loaded rows, `models_controller.rb:65`).

### 5. Public API — `app/controllers/api/v1/models_controller.rb`

Already emits `modality_class`; it will report `"image_generation"` with no code
change. Add nothing new for directory-first beyond ensuring a nil price serialises
as `null` (it does — accessors are `&.`). A `"priced": false` / `"price_note"` key
is deferred with per-image pricing.

### 6. Seeds & fixtures

- **Seeds** (`db/seeds.rb`): add 2–3 well-known image-gen models as **curated**
  rows with `input_modalities`/`output_modalities` set and **no** price point, so
  the category ships non-empty and demonstrable even before a sync. (nano banana
  arrives via sync already; seeds cover the OpenRouter-absent names.)
- **Fixtures/tests:** extend the OpenRouter sync test with an image-output,
  zero-priced row and assert it's admitted, classed `image_generation`, price-less,
  and `listed`. Add a `models_controller` test that the `image_generation` facet
  filters. Add a model-page test that a directory listing renders "not yet tracked",
  not "$0".

## Risks & where they bite

- **`listed` widening** changes *which models exist* on the public surface — the
  same "real product risk" the parent plan flagged for its Phase 2. Reviewed on its
  own; the OR-clause is scoped strictly to `DIRECTORY_CLASSES` so nothing else
  leaks in.
- **Headline/sort pollution:** verified nil-safe by inspection (`SORTS` infinity
  guard, `cheapest`/`default_baseline` filter on `input`), but each gets an explicit
  test rather than a promise.
- **nano banana's token price:** kept and shown (it's real). If we later decide an
  image model's token price is more confusing than helpful, that's a display
  choice we can revisit — out of scope here.

## Out of scope (later phases, per the parent plan)

- Per-image / per-second **native pricing** (curated `native_price_usd` column,
  nullable text rates) — the parent plan's Phase 4.
- TTS / STT / video / embedding classes — same pattern, one class at a time, once
  image generation validates the shape.
- Admin modality editing — sync + seeds cover v1; the admin form gains a modality
  editor when curated directory pricing lands.

## Green gate

Ends on the `preflight` skill (RuboCop, Brakeman, bundler-audit, importmap audit,
full test suite, seed replant) before push, per `CLAUDE.md`. Credential-touching
tests stub with `stub_anthropic_key!` / `stub_admin_digest!`.

## Ship order (one PR)

1. `ModalityClass` + tests (pure addition, no behaviour change yet).
2. `listed` scope + `directory_listing?` + tests.
3. Sync admission of price-less directory rows + tests.
4. View/price-cell + model-page + facet copy.
5. Seeds + fixtures.
6. Preflight, push.
