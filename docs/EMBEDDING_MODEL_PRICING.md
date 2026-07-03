# Text-embedding model pricing — sourced dataset

> **As of 2026-07-03.** The authoritative input for the text-embedding category
> (seeds + display). Embeddings bill **per input token only** — the output is a
> vector, so there is no output-token charge. All headline figures are stated as
> **USD per 1M input tokens**. Every figure is cited and confidence-rated;
> anything not confirmable on a primary source is listed in **Do not publish as
> fact** at the bottom and must render as "not published / not verified", never a
> guessed number. Companion to `docs/IMAGE_MODEL_PRICING.md` (same format).

## How to read this

- **Price /1M** — USD per 1M input tokens (standard/synchronous tier). Where a
  batch tier exists it is noted; batch is typically 50% of standard.
- **Dimensions** — native output vector size. Many models expose Matryoshka
  (MRL) truncation, shown as "native (down to N)".
- **Max input** — per-request context in tokens.
- **On OpenRouter?** — whether OpenRouter's embeddings endpoint currently lists
  the model, i.e. whether our daily OpenRouter sync would pick it up
  automatically. OpenRouter added a real `/v1/embeddings` endpoint and an
  embedding-models collection in 2026, so this is now a meaningful column.
- `conf` = confidence: **H** primary source (provider's own page), **M**
  corroborated across sources but primary page gated/JS-rendered or reseller-only,
  **L** not confirmable on a primary source.

Note on units: OpenAI, Cohere, Voyage, Mistral, Jina, Nomic and the Gemini API
all bill embeddings **per token**. Google **Vertex AI** (`text-embedding-005`,
`text-multilingual-embedding-002`) is the exception — it bills **per 1,000
input characters**, so its per-token figure is not directly comparable and is
flagged below.

## OpenAI

| Model | Price /1M | Dimensions | Max input | OpenRouter? | conf | Source (as of 2026-07-03) |
|---|---|---|---|---|---|---|
| **text-embedding-3-small** | $0.02 (batch $0.01) | 1536 (down to 512) | 8,191 | **yes** | H | developers.openai.com/api/docs/models/text-embedding-3-small · openrouter.ai/openai/text-embedding-3-small |
| **text-embedding-3-large** | $0.13 (batch $0.065) | 3072 (down to 256) | 8,191 | **yes** | H | developers.openai.com/api/docs/models/text-embedding-3-large · openrouter.ai listing |
| **text-embedding-ada-002** (legacy) | $0.10 | 1536 (fixed) | 8,191 | no | M | price widely published, primary page de-emphasised; superseded by 3-small/large |

## Cohere

Cohere does not expose a fetchable per-token pricing table (the pricing page
renders Model Vault instance pricing; token rates are JS/reseller-sourced). Text
rates below are corroborated across docs + resellers (AWS Bedrock, calculators);
treat as **M**.

| Model | Price /1M | Dimensions | Max input | OpenRouter? | conf | Source (as of 2026-07-03) |
|---|---|---|---|---|---|---|
| **Embed 4** (`embed-v4.0`) | $0.12 text · ~$0.47 image tokens | 1536 (MRL 256/512/1024/1536) | 128,000 | no | M | docs.cohere.com/docs/cohere-embed · Bedrock/reseller calculators |
| **Embed English v3** (`embed-english-v3.0`) | $0.10 | 1024 | 512 | no | M | docs.cohere.com/docs/models · AWS Marketplace |
| **Embed Multilingual v3** (`embed-multilingual-v3.0`) | $0.10 | 1024 | 512 | no | M | docs.cohere.com/docs/models · AWS Marketplace |

## Voyage AI

Primary pricing table (docs.voyageai.com/docs/pricing) fetched directly — **H**.
The lineup has moved to the **voyage-4** family; the voyage-3.x models are still
listed (as "older models", no free tier). All family members share MRL dims
(256/512/1024/2048, default 1024) and 32,000-token context.

| Model | Price /1M | Dimensions | Max input | OpenRouter? | conf | Source (as of 2026-07-03) |
|---|---|---|---|---|---|---|
| **voyage-4-large** | $0.12 | 1024 (256/512/1024/2048) | 32,000 | no | H | docs.voyageai.com/docs/pricing |
| **voyage-4** | $0.06 | 1024 (256/512/1024/2048) | 32,000 | no | H | same |
| **voyage-4-lite** | $0.02 | 1024 (256/512/1024/2048) | 32,000 | no | H | same |
| **voyage-3-large** | $0.18 | 1024 (256/512/1024/2048) | 32,000 | no | H | same |
| **voyage-3.5** | $0.06 | 1024 (256/512/1024/2048) | 32,000 | no | H | same |
| **voyage-3.5-lite** | $0.02 | 1024 (256/512/1024/2048) | 32,000 | no | H | same |
| **voyage-code-3** | $0.18 | 1024 (256/512/1024/2048) | 32,000 | no | H | same |
| **voyage-context-3** | $0.18 | 1024 (256/512/1024/2048) | 32,000 | no | H | same |

## Google

Gemini API embedding prices confirmed on the primary pricing page
(ai.google.dev/gemini-api/docs/pricing) — **H**. `text-embedding-005` is a
**Vertex AI** model billed per 1k characters, not per token — its per-token
figure is not published and is not comparable; flagged **L**.

| Model | Price /1M | Dimensions | Max input | OpenRouter? | conf | Source (as of 2026-07-03) |
|---|---|---|---|---|---|---|
| **gemini-embedding-001** | $0.15 (batch $0.075) | 3072 (MRL, e.g. 1536/768/256) | 2,048 | **yes** | H | ai.google.dev/gemini-api/docs/pricing · openrouter.ai embedding collection |
| **gemini-embedding-2** | $0.20 (batch $0.10) | 3072 (MRL) — dims not primary-confirmed | 2,048 (not confirmed) | **yes** | price H · dims/ctx M | ai.google.dev/gemini-api/docs/pricing · openrouter.ai |
| **text-embedding-005** (Vertex) | per 1k chars, not per token — see below | 768 (down to lower) | 2,048 | no | L | cloud.google.com/vertex-ai pricing (character-billed) |

## Mistral

Codestral Embed price confirmed on Mistral's own launch page
(mistral.ai/news/codestral-embed) — that figure is **H**; `mistral-embed`'s
$0.10 is widely cited but the API pricing table did not render on fetch, so
**M**.

| Model | Price /1M | Dimensions | Max input | OpenRouter? | conf | Source (as of 2026-07-03) |
|---|---|---|---|---|---|---|
| **mistral-embed** (`mistral-embed-2312`) | $0.10 | 1024 | 8,192 | **yes** (as "Mistral Embed 2312") | M | mistral.ai/pricing (JS) · openrouter.ai embedding collection |
| **codestral-embed** (`codestral-embed-2505`) | $0.15 (batch 50% off) | 3072 (default 1536, MRL truncatable) | 8,192 | no | price H · specs M | mistral.ai/news/codestral-embed · docs.mistral.ai/models/codestral-embed-25-05 |

## Jina AI

Jina bills all embedding models from one shared, top-up token pool (10M free
tokens per new key). The public pricing page is dashboard/JS-gated and did not
render a per-token rate on fetch; the widely-cited standard rate is $0.02/1M.
Treat the price as **L**. Note `jina-embeddings-v4` is released under the Qwen
Research License (non-commercial), which is why Jina's page labels it "free" —
do not read that as the commercial API rate.

| Model | Price /1M | Dimensions | Max input | OpenRouter? | conf | Source (as of 2026-07-03) |
|---|---|---|---|---|---|---|
| **jina-embeddings-v3** | ~$0.02 (shared token pool) | 1024 (MRL down to 32) | 8,192 | no | L | jina.ai/embeddings (JS-gated) |
| **jina-embeddings-v4** | not confirmed (page shows "free"; commercial rate unclear) | 2048 (down to 128) | 32,768 | no | price L · specs M | jina.ai/embeddings · huggingface.co/jinaai/jina-embeddings-v4 |

## Nomic

Nomic's models are open-weight (Apache-2.0) and most cheaply run self-hosted or
via third-party inference (Fireworks ≈ $0.01/1M). Nomic's own hosted API rate is
cited at $0.10/1M but is not on a fetchable primary pricing page (the pricing
page bundles Atlas seats/storage), so **L**.

| Model | Price /1M | Dimensions | Max input | OpenRouter? | conf | Source (as of 2026-07-03) |
|---|---|---|---|---|---|---|
| **nomic-embed-text-v1.5** | ~$0.10 Nomic API · ~$0.01 Fireworks (open weights → self-host $0) | 768 (MRL down to 64) | 8,192 | no | L | nomic.ai/pricing (bundled) · Fireworks listing |
| **nomic-embed-text-v2-moe** | not confirmed (open weights; MoE) | 768 | 512 | no | L | ollama.com/library/nomic-embed-text-v2-moe · secondary |

## Also present on OpenRouter (open-weight, would auto-sync)

The OpenRouter embedding collection also lists these — relevant only because our
sync would ingest them automatically:

| Model | Provider | Price /1M | conf | Source |
|---|---|---|---|---|
| **Qwen3 Embedding 8B** | Qwen | $0.01 | M | openrouter.ai/collections/embedding-models |
| **Qwen3 Embedding 4B** | Qwen | $0.02 | M | same |
| **bge-m3** | BAAI | $0.01 | M | same |
| **Embed V1 0.6B** | Perplexity | $0.004 | M | same |
| **Llama Nemotron Embed VL 1B V2** | NVIDIA | $0 (free) | M | same |

## Do not publish as fact (unconfirmed / caveated)

1. **Cohere token rates** ($0.12 Embed 4, $0.10 v3, ~$0.47 image tokens) — Cohere
   publishes no fetchable per-token table; corroborated only via docs prose +
   Bedrock/reseller calculators. Publish as **M**, not as a primary quote.
2. **Cohere Embed 4 image-token rate (~$0.47/1M)** — reseller-only; lower
   confidence than the text rate.
3. **Jina per-token rate ($0.02/1M)** — not confirmed on a primary page; the
   pricing page is JS/dashboard-gated. `jina-embeddings-v4`'s commercial price is
   genuinely unclear (page shows "free" under a non-commercial research license).
4. **Nomic hosted API rate ($0.10/1M)** — not on a fetchable primary pricing
   page; Atlas pricing bundles seats/storage. Third-party ($0.01 Fireworks) and
   self-host ($0) are the realistic paths. `nomic-embed-text-v2-moe` price not
   found at all.
5. **`gemini-embedding-2` dimensions and max context** — price is primary (H);
   3072-dim/2,048-token specs are inferred from the -001 lineage, not confirmed
   for -2. Do not publish the specs as fact.
6. **`text-embedding-005` (Vertex)** — billed **per 1,000 characters**, not per
   token; do not synthesize a per-1M-token figure. It remains available on Vertex
   (not deprecated as of this date) but is legacy relative to gemini-embedding-*.
7. **`text-embedding-ada-002`** — legacy; keep for completeness, mark superseded.
8. **OpenRouter open-weight rows (Qwen3, bge-m3, Perplexity Embed, Nemotron)** —
   prices are from the OpenRouter collection listing (M); verify at sync time.

## OpenRouter sync coverage

Models the daily OpenRouter sync **picks up automatically** (present in the
embedding collection): OpenAI `text-embedding-3-small`, `text-embedding-3-large`;
Google `gemini-embedding-001`, `gemini-embedding-2`; Mistral `mistral-embed`
(as "Mistral Embed 2312"); plus open-weight extras (Qwen3 Embedding 8B/4B,
BAAI bge-m3, Perplexity Embed V1 0.6B, NVIDIA Llama Nemotron Embed VL 1B V2).

Models that must be **seeded manually** (not on OpenRouter): all of **Cohere**
(Embed 4, Embed v3 en/multi), all of **Voyage** (voyage-4/3.x family), **Jina**
(v3/v4), **Nomic** (v1.5/v2-moe), OpenAI **ada-002** (legacy), and Google
**text-embedding-005** (Vertex-only, character-billed).
