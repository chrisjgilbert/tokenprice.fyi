# Reranker model pricing — sourced dataset

> **As of 2026-07-11.** The authoritative input for the reranker
> (rerank / relevance-scoring) category (seeds + display). Rerankers do **not**
> share a billing unit, and there is **no single comparable headline**: some
> providers bill **per search** (one query scored against a batch of documents),
> others bill **per 1M tokens** (query + document tokens). This category shows
> each model in its **native unit** as a short price string — like the
> image-generation category — and never flattens the two units into one column.
> Every figure is cited and confidence-rated; anything not confirmable on a
> primary source is listed in **Do not publish as fact** at the bottom and must
> render as "not published / not verified", never a guessed number. Companion to
> `docs/EMBEDDING_MODEL_PRICING.md` and `docs/IMAGE_MODEL_PRICING.md` (same format).

## How to read the pricing model

Two native units appear, tagged with a one-word **pricing-model** label:

- **per_search** — billed per search (a "search" / "query" = one query scored
  against a batch of up to N documents). The headline is stated as a price per
  1,000 searches, e.g. "$2.00 / 1K searches". The **billing basis** column says
  what one search includes (max docs, per-doc token cap, chunking rule).
- **token_based** — billed per 1M tokens of **query + documents combined**. The
  headline is "$X / 1M tokens". The billing basis says exactly which tokens are
  metered (most reranker APIs charge query tokens once per document, so long
  candidate lists dominate the bill).

The two units are **not** interchangeable. A per-search price hides how many
documents/tokens a search carries; a per-token price hides how many searches a
budget buys. The directory keeps each in its own unit.

`conf` = confidence: **H** primary source (provider's own page), **M**
corroborated across sources but the primary page is gated/JS-rendered or the
rate is reseller/marketplace-only, **L** not confirmable on a primary source
(see bottom).

## Cohere

Cohere's public pricing page (`cohere.com/pricing`) now renders only **Model
Vault** instance pricing (dedicated deployments, e.g. ~$5/hr per Medium
instance); it no longer exposes a fetchable per-search rate. The per-search
figure below is the long-standing rate, corroborated on **AWS Bedrock**
($2.00 per 1,000 queries for `rerank-v3.5`); note **OpenRouter resells the same
model at $0.001/search (= $1.00/1K)**, so the headline is **M**, not a primary
quote. The definition of a "search" **is** on Cohere's docs (`docs.cohere.com/docs/rerank`) — that part is **H**.

| Model | Pricing model | Headline (native) | Billing basis + limits | conf | Source (as of 2026-07-11) |
|---|---|---|---|---|---|
| **Rerank 3.5** (`rerank-v3.5`) | per_search | **$2.00 / 1K searches** ($0.002/search) | 1 search = 1 query + up to **100 documents**. Any document whose tokens + the query exceed **500 tokens** is auto-chunked, and **each chunk counts as one more document** toward the 100 (so long docs inflate the search's effective doc count). | price **M** · search-def **H** | docs.cohere.com/docs/rerank (definition) · aws.amazon.com/bedrock/pricing ($2/1K) · cohere.com/pricing (Model Vault only) |

## Voyage AI

Primary pricing table (`docs.voyageai.com/docs/pricing`) fetched directly — **H**.
Voyage bills reranking **per token**, metering `(query_tokens × num_documents) +
sum(document_tokens)` — i.e. the query is charged once **per document**, so the
document count drives the bill. The current lineup is the **rerank-2.5** family;
`rerank-2` / `rerank-2-lite` remain listed as legacy (same rates, no free tier).

| Model | Pricing model | Headline (native) | Billing basis + limits | conf | Source (as of 2026-07-11) |
|---|---|---|---|---|---|
| **rerank-2.5** | token_based | **$0.05 / 1M tokens** | Meters (query tokens × #docs) + Σ(doc tokens). First **200M tokens free** per account. | H | docs.voyageai.com/docs/pricing |
| **rerank-2.5-lite** | token_based | **$0.02 / 1M tokens** | Same metering; first **200M tokens free** per account. | H | same |
| **rerank-2** (legacy) | token_based | $0.05 / 1M tokens | Same metering; **no** free tier. | H | same |
| **rerank-2-lite** (legacy) | token_based | $0.02 / 1M tokens | Same metering; **no** free tier. | H | same |

## Jina AI

Jina bills rerankers from the **same shared, top-up token pool as its embeddings**
(10M free tokens per new API key). The public reranker page confirms that
structure but the per-token **rate is dashboard/JS-gated** and did not render on
fetch, so every Jina price below is **L** (aggregator/calculator-sourced). Jina's
reranker weights are published under **CC-BY-NC-4.0** (research/non-commercial) —
"weights available" is not the same as free commercial use; the hosted API is the
commercial path.

| Model | Pricing model | Headline (native) | Billing basis + limits | conf | Source (as of 2026-07-11) |
|---|---|---|---|---|---|
| **jina-reranker-v3** (flagship) | token_based | ~$0.05 / 1M tokens (input; output free) | Shared token pool (query + docs). Up to **131K-token context**, ranks up to **64 docs** per call. Weights CC-BY-NC-4.0. | price **L** · specs **H** | jina.ai/reranker · jina.ai/models/jina-reranker-v3 (specs) · getmaxim/aggregator (price) |
| **jina-reranker-m0** (multimodal) | token_based | ~$0.05 / 1M tokens | Shared token pool; multilingual + multimodal (text/image docs). Weights CC-BY-NC-4.0. | L | jina.ai/models/jina-reranker-m0 · aggregator |
| **jina-reranker-v2-base-multilingual** | token_based | ~$0.02 / 1M tokens | Shared token pool. Open weights (CC-BY-NC-4.0). | L | jina.ai/reranker · getmaxim/aggregator |

## Mixedbread

Mixedbread's `mxbai-rerank` weights are **open (Apache-2.0)** — self-host is $0.
Its **managed platform** bills reranking as part of search, **per query, not per
token**: usage-based **search at $0.10 / 1K queries** (indexing is separate, at
$1.50/1M tokens). The per-query rate is from `mixedbread.com/pricing` prose
(corroborated, page partly JS) → **M**. `mxbai-rerank-large-v2` is also published
on Together AI, but is **not on Together's serverless API** as of this date.

| Model | Pricing model | Headline (native) | Billing basis + limits | conf | Source (as of 2026-07-11) |
|---|---|---|---|---|---|
| **mxbai-rerank-large-v2** | per_search | **$0.10 / 1K queries** (managed platform) | Managed search billed per query; open weights (Apache-2.0) → self-host $0. Not on Together serverless. | M · self-host $0 | mixedbread.com/pricing · together.ai/models/mxbai-rerank-large-v2 (not serverless) |
| **mxbai-rerank-base-v2** | per_search | $0.10 / 1K queries (managed) | Same managed per-query basis; open weights (Apache-2.0) → self-host $0. | M · self-host $0 | mixedbread.com/docs/models/reranking/mxbai-rerank-base-v2 |

## ZeroEntropy

Primary pricing page (`zeroentropy.dev/pricing`) fetched directly — **H**. The
current reranker is **`zerank-2`**; the earlier `zerank-1` / `zerank-1-small`
(launched mid-2025) are superseded. ZeroEntropy bills **per 1M tokens** (query +
documents). `zerank-2` weights are published on Hugging Face.

| Model | Pricing model | Headline (native) | Billing basis + limits | conf | Source (as of 2026-07-11) |
|---|---|---|---|---|---|
| **zerank-2** (current) | token_based | **$0.025 / 1M tokens** | Meters query + document tokens. Weights available on Hugging Face. | H | zeroentropy.dev/pricing · huggingface.co/zeroentropy |
| **zerank-1 / zerank-1-small** (legacy) | token_based | $0.025 / 1M tokens (as launched) | Superseded by zerank-2; rate no longer on the live pricing page. | price **L** (delisted) | zeroentropy.dev/articles/announcing-zeroentropy-s-first-rerankers |

*(ZeroEntropy also lists `zembed-1` embeddings at $0.050/1M — out of scope for
this reranker dataset, noted so the number isn't mistaken for a rerank rate.)*

## Pinecone (hosted rerank)

Primary pricing page (`pinecone.io/pricing`) fetched directly — **H**. Pinecone
Inference hosts several rerankers and bills them **per request (per search)**, not
per token: **$2.00 per 1,000 requests** (a "rerank_unit") on Standard/Enterprise,
uniform across models. Only `bge-reranker-v2-m3` is available on the lower
Starter/Builder tiers (with small monthly included allotments).

| Model | Pricing model | Headline (native) | Billing basis + limits | conf | Source (as of 2026-07-11) |
|---|---|---|---|---|---|
| **cohere-rerank-4-fast** (latest) | per_search | **$2.00 / 1K requests** | 1 request = 1 query + up to **250 documents**, 8,192 tokens/doc. Standard/Enterprise only. | H | docs.pinecone.io/guides/search/rerank-results · pinecone.io/pricing |
| **cohere-rerank-3.5** (deprecated on Pinecone) | per_search | $2.00 / 1K requests | Up to **200 documents**, 40,000 tokens/query-doc pair. | H | same |
| **bge-reranker-v2-m3** | per_search | $2.00 / 1K requests | Up to **100 documents**, 1,024 tokens/query-doc pair. Available on all tiers (Starter/Builder have small included allotments). Open weights (Apache-2.0) upstream. | H | same |
| **pinecone-rerank-v0** | per_search | $2.00 / 1K requests | Up to **100 documents**, 512 tokens/query-doc pair. Pro plan. | H | same |

## Hosted open-weight rerankers (Together / Baseten / Fireworks / others)

`bge-reranker-v2-m3` (BAAI, Apache-2.0) is the canonical open-weight cross-encoder
reranker and is hosted by many inference providers at a **per-1M-token** rate.
Rates vary widely by host and none render on a clean primary pricing page for the
reranker specifically, so treat these as **L–M**; self-hosting is $0 + compute.

| Model | Host(s) | Pricing model | Headline (native) | conf | Source (as of 2026-07-11) |
|---|---|---|---|---|---|
| **bge-reranker-v2-m3** | Baseten, Novita, Cloudflare, others | token_based | ~$0.01 / 1M tokens (Novita-class; varies by host) | L–M · self-host $0 | baseten.co/library/bge-reranker-m3 · cloudprice/novita listing |
| **mxbai-rerank-large-v2** | Featherless, Together (not serverless) | token_based / flat | not cleanly primary-confirmed; open weights → self-host $0 | L · self-host $0 | featherless.ai/models/mixedbread-ai/mxbai-rerank-large-v2 |

## NVIDIA NIM rerank

`nv-rerankqa-mistral-4b-v3` (NeMo Retriever Reranking NIM) ships as a
**self-hosted container**; there is **no public per-search or per-token list
price** — it is consumed under **NVIDIA AI Enterprise** licensing / your own GPU,
with a free preview on `build.nvidia.com`. No publishable per-unit rate.

| Model | Pricing model | Headline (native) | Billing basis + limits | conf | Source (as of 2026-07-11) |
|---|---|---|---|---|---|
| **nv-rerankqa-mistral-4b-v3** | self-host / NIM | not published (NIM container; NVIDIA AI Enterprise / self-host) | 4B cross-encoder; billed via GPU/enterprise license, not per search or per token. Free preview on build.nvidia.com. | price ✗ · model H | build.nvidia.com/nvidia/nv-rerankqa-mistral-4b-v3 · docs.nvidia.com/nim/nemo-retriever |

## The two native units — which model is which

**per_search** (billed per query-against-a-batch; a search hides its doc/token
count):
- **Cohere** Rerank 3.5 — $2.00 / 1K searches (1 query + ≤100 docs)
- **Pinecone** hosted rerankers (cohere-rerank-4-fast, cohere-rerank-3.5,
  bge-reranker-v2-m3, pinecone-rerank-v0) — $2.00 / 1K requests
- **Mixedbread** managed platform — $0.10 / 1K queries

**token_based** (billed per 1M tokens of query + documents; a token price hides
its search count):
- **Voyage** rerank-2.5 ($0.05) / rerank-2.5-lite ($0.02)
- **Jina** reranker-v3 / m0 (~$0.05) / v2-base-multilingual (~$0.02)
- **ZeroEntropy** zerank-2 ($0.025)
- **Hosted open-weight** bge-reranker-v2-m3 (~$0.01, varies by host)

## Open-weight vs API-only

- **Open weights** (self-host $0 + compute; hosted rate shown where offered):
  - **bge-reranker-v2-m3** — BAAI, **Apache-2.0** (fully permissive).
  - **mxbai-rerank** (large/base v2) — Mixedbread, **Apache-2.0** (managed API
    ~$0.10/1K queries; self-host free).
  - **zerank-2** — ZeroEntropy, weights on Hugging Face (verify license before
    commercial self-host; hosted $0.025/1M).
  - **jina-reranker-v3 / m0 / v2** — Jina, **CC-BY-NC-4.0** (weights available but
    **non-commercial**; commercial use = the hosted API).
  - **nv-rerankqa-mistral-4b-v3** — NVIDIA NIM (self-host under NVIDIA AI
    Enterprise; no public per-unit rate).
- **API-only / closed** (no self-host):
  - **Cohere** Rerank 3.5 · **Voyage** rerank-2.5 family.

## Do not publish as fact (unconfirmed / caveated)

1. **Cohere Rerank 3.5 per-search rate** — Cohere's own pricing page shows only
   **Model Vault** instance pricing, not a per-search rate. Publish **$2.00 / 1K
   searches** as **M** (AWS Bedrock-corroborated), and note the conflict:
   **OpenRouter resells the same model at $0.001/search = $1.00/1K**. Do not
   present either as a primary Cohere quote. (The *definition* of a search is
   primary/H.)
2. **All Jina reranker prices** (v3, m0, v2 ≈ $0.05/$0.05/$0.02/1M) — not
   confirmed on a primary page; the reranker/embeddings pricing is dashboard/JS-
   gated. Figures are from cost-calculator aggregators (**L**). Specs (131K ctx,
   64 docs, CC-BY-NC-4.0 license) **are** primary (H).
3. **Mixedbread managed per-query rate ($0.10/1K queries)** — from pricing-page
   prose, page partly JS-rendered; corroborated but **M**. It is a *managed-search*
   per-query charge, not a published per-model rerank API rate. Self-host is the
   confident path ($0, Apache-2.0).
4. **`mxbai-rerank-large-v2` on Together** — the model page states it is **not on
   Together's serverless API**; do not publish a Together per-token rerank price
   for it. Featherless/flat-rate hosting exists but was not primary-confirmed (L).
5. **ZeroEntropy `zerank-1` / `zerank-1-small`** — superseded by `zerank-2`; the
   $0.025/1M rate is no longer on the live pricing page (delisted). Publish only
   **zerank-2** ($0.025/1M, H) as current.
6. **Hosted `bge-reranker-v2-m3` per-token rates** — vary from ~$0.0014 to $75/1M
   across 34 providers (aggregator range); the ~$0.01/1M figure is Novita-class,
   not a single canonical rate. Publish as **L–M** with "varies by host"; the
   reliable facts are "open weights, Apache-2.0, self-host $0".
7. **NVIDIA `nv-rerankqa-mistral-4b-v3`** — **no public per-search or per-token
   list price**. It is a self-hosted NIM under NVIDIA AI Enterprise. Do not
   synthesize a per-unit number; display "pricing not published / self-host".
8. **Voyage `rerank-2` / `rerank-2-lite` (legacy)** — still listed at $0.05/$0.02
   but with **no free tier**; keep for completeness, mark legacy. Only the
   **rerank-2.5** family carries the 200M-free-token allowance.
9. **`zembed-1` ($0.050/1M)** — a ZeroEntropy *embedding*, not a reranker; listed
   here only to prevent it being mistaken for a rerank rate.
