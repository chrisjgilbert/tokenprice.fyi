# Embeddings tab — spec

> **Status:** Proposed. The third pricing category after `language` and `image`
> (see `docs/IMAGE_CATEGORY_PLAN.md` and the tabs work in PR #114). Read the
> **Architecture** and **Copy style** sections of `CLAUDE.md` first.

## Why embeddings next

Embeddings are the one non-language category that **prices in the same unit the
app is built on** — USD per 1M **input** tokens. Consequences:

- **Real prices from day one, not curated placeholders.** OpenRouter lists
  embedding models with a real prompt price (the sync test already carries
  `openai/text-embedding-3`, `prompt: "0.00000002"`, `completion: "0"`,
  output `["embedding"]`). Unlike image generation, nothing has to be hand-priced.
- **Maximum reuse.** `input_per_mtok`, the price-sort machinery, `token_priced?`,
  the `listed` scope (embeddings have a price point, so they list normally), and
  the estimator all work as-is. Embeddings sort by price — the thing that
  matters — which image can't.
- **Directly serves the mission.** Embeddings are a dominant RAG cost driver, and
  the guide already teaches RAG. An embeddings price table feeds that story.

The catch, and the only real design work, is that an embedding has **input tokens
but no output tokens** — its output is a vector. So the per-token schema, which
assumes an input *and* output rate, has to admit an input-only price.

## 1. The pricing-storage decision (the crux)

`price_points` today: `input_per_mtok` and `output_per_mtok` are both `NOT NULL`,
`text_rates_present_together` requires both-or-neither, `prices_something`
requires input. An embedding has input only.

**Decision: make `output_per_mtok` nullable and allow an input-only price for
embedding-class models.** Storing `output_per_mtok = 0` is rejected — it reads as
"priced at $0 per output token", a lie (there are no output tokens), and would
serialise as `output: 0` in the API. Null is the honest representation.

- **Migration:** `change_column_null :price_points, :output_per_mtok, true`.
  `input_per_mtok` stays `NOT NULL` (every priced row has an input rate).
- **Validation (`app/models/price_point.rb`):** relax `text_rates_present_together`
  so an **input-only** price is valid *for an embedding-class model*; keep
  "both-or-neither" for everyone else (a text model with input-but-no-output is
  still a half-entered price to catch). The rule is model-aware:
  `output_optional = ai_model&.modality_class == :embedding`. `prices_something`
  is unchanged (input still required).
- **Blast radius:** text models keep both rates (unaffected); image models have no
  price points (unaffected). Only embeddings store input-only. `current_output`
  returns nil for embeddings — fine, they're on a tab with no output column, and
  the price-change math already returns nil when a rate is missing.

## 2. Admit embeddings in the OpenRouter sync

`ModelSync#import` (`app/models/open_router/model_sync.rb`) currently prices a row
only when it outputs text (`prices_per_token = pricing && (output empty ||
includes "text")`), so an embedding (output `["embedding"]`) is skipped.

- Broaden the token-priced test to include embedding output:
  `prices_input_token = pricing && (outputs_text || outputs_embedding)`, where
  `outputs_embedding = model.output_modalities == %w[embedding]`.
- When recording an **embedding** price, write the input rate and **null the
  output** (OpenRouter sends `completion: "0"`, which is meaningless for an
  embedding — don't persist it as a real 0). Simplest: in `record_price`, pass
  `output: nil` for embedding-class models; keep the existing path for text.
- The Slack digest formats an input/output pair — for an embedding, report the
  input rate only (or leave it out of the digest, like directory rows). Pick the
  cleaner; a "$0 output" line in Slack is the same lie to avoid.
- `same_price?` / reprice detection: compare on input (and the nil output) so an
  embedding doesn't churn a fresh snapshot every run.

## 3. ModelCategory — add the tab, and fix membership

`app/models/model_category.rb` gains an `EMBEDDINGS` entry. But first, membership
needs a small refactor: today `LANGUAGE.matcher` is `!directory_class?(mc)`, which
**includes** embedding. With embeddings getting their own tab, a class must belong
to exactly one category.

**Refactor to "language is the fallback":** non-language categories declare their
class(es); `LANGUAGE.member?(mc)` becomes "no other category claims `mc`". Then
adding a future tab never edits language's matcher again (it already promises
"adding a tab is a registry entry + a route").

```ruby
# image claims :image_generation; embeddings claims :embedding; language is the rest.
def self.for_class(mc) = ALL.find { |c| c != LANGUAGE && c.claims?(mc) } || LANGUAGE
# LANGUAGE.claims? is never called; its membership is "unclaimed by others".
```

`EMBEDDINGS` entry: slug `"embeddings"`, path `/embeddings` (route
`get "embeddings", to: "models#index", defaults: { category: "embeddings" }`),
claims `:embedding`, sorts `%w[input context name provider released]`, default
sort **`input` asc** (cheapest first — the natural embeddings question), title +
meta_description in the copy style ("Text embedding API prices, per 1M tokens…").

## 4. Generalize the column layout (the deferred column-as-data)

Two categories justified a `token_columns` boolean. **Three don't** — embeddings
need a *third* column set (input but no output/cached). This is the moment the
column-as-data refactor the review flagged earns its keep.

Give each category a declared **column list** instead of the boolean:

```ruby
# each column key maps to a header (label + sort key) and a cell renderer
columns: %i[name provider input context released]   # embeddings
columns: %i[name tier input output cached context]  # language
columns: %i[name provider pricing released]          # image
```

The view iterates `@category.columns` for the `<thead>` (sort_link only when the
key is in `@category.sorts`) and the row `<td>`s (a small `case key` → cell
partial/helper). `empty_colspan` derives from `columns.size` (+ the select/go
cols), so no magic number. `shows_tier_facet` can stay, or become
`facets: %i[search provider tier]` per category — either is fine; the column list
is the load-bearing change.

This replaces the `@category.token_columns` / `slug`-ish branches with data, so
the embeddings tab (and any future tab) is columns + sorts + a route, no new view
conditionals.

## 5. Dimensions (recommended, small)

Embedding buyers compare on **vector dimensions** (768 / 1536 / 3072) — it drives
downstream vector-store cost and recall, and it's the second axis after price. Add
an integer `dimensions` column to `ai_models` (nullable; only embeddings set it),
show it as a column on the embeddings tab, and let the sync fill it from
OpenRouter where present (else curated/seeded). Defer only if we want the leanest
possible v1 — but it's cheap and it's the fact embeddings shoppers ask for.

## 6. Data

- **Sync:** admits OpenRouter's embedding models automatically once §2 lands.
- **Seed** the well-known ones with real per-1M-**input** prices + sources (as the
  image roster did), since not all are on OpenRouter: OpenAI `text-embedding-3-small`
  ($0.02) / `-large` ($0.13), Cohere `embed-v4`, Voyage `voyage-3`(-large/-lite),
  Google `gemini-embedding`, Mistral `mistral-embed`, Jina `jina-embeddings-v3`,
  Nomic `nomic-embed-text`. Prices need a sourced verification pass (like
  `docs/IMAGE_MODEL_PRICING.md`) before seeding — do not publish from memory.
- New providers to add as needed: Voyage AI, Jina AI, Nomic (Cohere/Mistral/Google/
  OpenAI already exist).

## 7. Display & the model page

- **Embeddings tab columns:** Model · Provider · Input /1M · Dimensions · Context ·
  Released. Sortable by input (default, asc), name, provider, released. The input
  cell reuses `usd(model.current_input)`; the price-sort already sinks a price-less
  row, though every listed embedding has an input price.
- **Model page (`show`):** an embedding is `priced?` (has a price point), so it hits
  the per-token card grid. Output/Cached cards would render "—". Either accept that
  (honest — embeddings have neither) or show an embedding-specific card set (Input,
  Dimensions, Context). Recommend the small per-class card tweak so the page doesn't
  show two empty cards.
- **API:** additive — `price_per_mtok.output` is already nullable in the JSON; an
  embedding reports input set, output null. Add `dimensions` if §5 lands.

## 8. Tests

- `PricePoint`: an input-only price is valid for an embedding model, invalid for a
  text model (both-together still enforced there).
- Sync: an embedding-output row with a prompt price is admitted, priced input-only
  (output nil, not 0), listed, and reprice-stable across runs.
- `ModelCategory`: `for_class(:embedding)` → embeddings; language no longer claims
  embedding; the column list drives thead/row.
- Controller/view: `/embeddings` lists embedding models with an Input column and a
  working input-price sort; language and image tabs unchanged; a tab strip with
  three tabs + counts; canonical + per-tab SEO; sitemap includes `/embeddings`.
- Fixtures: add an embedding model (input-only price point, modality_class
  `embedding`, dimensions set).

## 9. Decisions to confirm before building

1. **Nullable `output_per_mtok`** (recommended) vs storing 0 — settles the storage.
2. **Include `dimensions`** (recommended) vs defer.
3. **Column-as-data refactor** (recommended — three column sets justify it) vs
   another per-category boolean.
4. **Default sort `input` asc** (cheapest first) for the embeddings tab.

## 10. Ship order (sub-agent TDD, per the established rhythm)

1. **Storage** — migration (nullable output, `dimensions`), `PricePoint`
   model-aware validation, tests.
2. **Sync + data** — admit/price embeddings input-only; sourced seed roster +
   providers; sync + seed tests.
3. **Category + view** — `ModelCategory` membership refactor + `EMBEDDINGS` entry +
   column-as-data; the `/embeddings` route, tab, columns, sorts, sitemap; tests.

Each phase green before the next; then `/code-review --fix`, `/simplify`,
`/verify`, PR, merge on green. Pricing figures get a sourced verification pass
(mirroring `docs/IMAGE_MODEL_PRICING.md`) before anything is seeded.
