# Rerank category tab — plan

> The seventh pricing-table category, grouped with embeddings as the retrieval
> pair. A reranker takes a query and a set of documents and returns relevance
> scores. Two things make it distinct: it needs a **synthetic output modality**
> (`rerank`, mirroring how `embedding` works — no provider reports it, we set it
> on the seeds), and its pricing is **genuinely split** between per-search
> (Cohere) and per-1M-tokens (Voyage, Jina), with no comparable single unit — so
> it's **image-generation-shaped**: heterogeneous `price_summary` strings + a
> `pricing_model` badge, not a sortable rate. Companion to
> `docs/IMAGE_CATEGORY_PLAN.md`.

## Why it's shaped like image, keyed like embedding

- **Keyed like embedding:** rerank's input/output signature has no natural token
  in the modality vocabulary. Embeddings solved the same problem with a synthetic
  `embedding` output modality set explicitly on the seeds. Rerank adds a `rerank`
  output modality the same way — `text → rerank`.
- **Shaped like image:** Cohere bills **per search** ($2 / 1K searches), Voyage
  and Jina bill **per 1M tokens** ($0.02–0.05 / 1M). These aren't comparable, and
  normalizing one into the other would fabricate a number (a "search" bundles a
  query + up to N documents of ≤M tokens — no honest per-token conversion). So,
  like image generation, each row shows its native price as a `price_summary`
  string with a `pricing_model` badge, and the column is not price-sortable.

Result: rerank reuses image's entire column/sort/`:pricing`-cell machinery, plus
the embedding pattern of an explicit output modality. Genuinely small surface.

## Classification

`ModalityClass` gains:
- `VOCABULARY` += `"rerank"` (a synthetic output modality, like `embedding` — it
  only ever appears on our curated seeds; nothing external reports it).
- A `rerank` rule, mirroring `embedding` (text in, the synthetic modality out):

```ruby
# in SIGNATURE_RULES, right after embedding:
embedding: -> { (@input - %w[image text]).empty? && @input.any? && embedding_output? },
rerank:    -> { @input == %w[text] && @output == %w[rerank] },
```

- `LABELS[:rerank] = "Rerank"`, `DESCRIPTIONS[:rerank] = "A query and documents in,
  relevance scores out."`, `DIRECTORY_CLASSES += :rerank` (native pricing, listed
  before priced, "not yet tracked" until curated).

`text → rerank` classifies as `:rerank`. Nothing existing reclassifies (`rerank`
is a brand-new token no current row carries).

## Storage

**None** (no migration). Reuses the curated native-pricing columns
(`pricing_model` / `price_summary` / `price_detail` / `price_source` /
`priced_as_of`) exactly as image does. Add to `PRICING_MODEL_LABELS`:
`"per_search" => "Per search"` (and reuse the existing `"token_based" =>
"Token-based"`). `AiModel#rerank? = modality_class == :rerank`.

## Category + view

`ModelCategory::RERANK`, inserted **after `EMBEDDINGS`** in `ALL` so the tab strip
groups the retrieval pair (embeddings · rerank):

```ruby
RERANK = Category.new(
  slug: "rerank",
  label: "Rerank",
  param: "rerank",
  path_name: :rerank,
  sorts: %w[name provider released],
  default_sort: "name",
  default_dir: "asc",
  title: "Reranker API pricing — tokenprice.fyi",
  meta_description: "Reranker (relevance-scoring) model pricing, in each model's native unit — " \
                    "per search or per 1M tokens. Native rates and pricing models, updated as providers publish them.",
  matcher: ->(mc) { mc == :rerank },
  columns: %i[name provider pricing released]
)

ALL = [ LANGUAGE, EMBEDDINGS, RERANK, SPEECH_TO_TEXT, TEXT_TO_SPEECH, IMAGE, VIDEO_GENERATION ].freeze
```

Same shape as `IMAGE`. Route:

```ruby
get "rerank", to: "models#index", defaults: { category: "rerank" }, as: :rerank
```

Controller, view, sitemap, and show page need **no change** — the `:pricing` cell,
non-price sorts, hidden tier facet, and registry-driven sitemap already handle it.

## Data

`docs/RERANK_MODEL_PRICING.md` — sourced dataset in the image doc's format, H/M
confidence only. Each row's native unit as a `price_summary` string. Roster:
Cohere (Rerank 3.5, per search), Voyage (rerank-2.5 / -lite, per token), Jina
(reranker v2 / m0, per token), Mixedbread (mxbai-rerank), Zeroentropy, Pinecone
hosted rerank, and open-weight bge-reranker (self-host $0 / hosted ~$X). New
providers as needed (voyage/jina exist from embeddings; add mixedbread,
zeroentropy, pinecone as they appear).

## No regressions

- `PriceCatalog.cheapest(tier:)` requires `input && output`, so rerank rows
  (no per-token rate) are excluded — same guard as image/STT/TTS/video.
- OpenRouter sync unchanged (rerank is curated-only; no external `rerank`
  modality means the sync never produces one).
- Language tab excludes rerank via the matcher.
- `PricingStaleness` picks rerank up automatically (a new non-language curated
  category), so the maintenance report covers it with no change.

## Tests (mirror image/embedding)

modality_class (`text→rerank` → rerank; label + directory-class; `rerank` in
VOCABULARY), ai_model (a rerank fixture: listed, native_priced?, rerank?,
price_headline shows the summary; a price-less rerank fixture is
directory_listing?), price_catalog (Entry + seam-parity + cheapest excludes),
model_category (ALL order, columns, for-resolution, SEO), models_controller (tab
lists rerank rows, Pricing column, hides tier facet, canonical/SEO, excluded from
other tabs). Sitemap auto-covered by the registry test.

## Ship order

1. **Storage + classification + category** — the `rerank` vocabulary token +
   modality rule + predicate + labels + `DIRECTORY_CLASSES`; the `RERANK`
   `ModelCategory` + route; `per_search` label; fixtures + tests. (Classification
   and category land together — a new directory class with no category leaks onto
   language.)
2. **Data** — sourced `docs/RERANK_MODEL_PRICING.md` + seed roster + providers.

Then `/code-review --fix`, `/verify`, PR, merge on green.
