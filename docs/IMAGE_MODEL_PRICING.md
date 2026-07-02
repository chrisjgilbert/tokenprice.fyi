# Image-generation model pricing — sourced dataset

> **As of 2026-07-01.** The authoritative input for the image-generation category
> (seeds + display). Every figure is cited and confidence-rated; anything not
> confirmable on a primary source is listed in **Do not publish as fact** at the
> bottom and must render as "not published / not verified", never a guessed
> number. Companion to `docs/IMAGE_CATEGORY_PLAN.md`.

## How to read the pricing model

Image models don't share a unit — the directory shows each in its native shape,
with a one-word **pricing-model** label, and never flattens them into one
comparable column:

- **Per image (flat)** — one price per generated image.
- **Per image (tiered)** — a price per tier/quality/variant.
- **Per megapixel** — scales with output resolution.
- **Token-based** — billed in tokens; we show the provider's published per-image
  equivalent at a stated size, with the mechanism noted.
- **Credit-based** — billed in credits; we show credits + the credit→USD basis.

`conf` = confidence: **H** primary source, **M** corroborated but primary page
gated/JS-rendered, **L**/✗ not confirmable (see bottom).

## OpenAI

| Model | Status | Pricing model | Price (native) | conf | Source |
|---|---|---|---|---|---|
| **gpt-image-2** | current flagship | token-based | per 1024² image: $0.006 / $0.053 / $0.211 (low/med/high). Tokens/1M: text in $5, image in $8, image out $30 | H | developers.openai.com/api/docs/pricing |
| **gpt-image-1.5** | active · retires 2026-12-01 | token-based | per 1024² image: $0.009 / $0.034 / $0.133 | tokens H · per-image M | same + /deprecations |
| **gpt-image-1-mini** | active · retires 2026-12-01 | token-based | per 1024² image: $0.005 / $0.011 / $0.036 | M | same |
| **gpt-image-1** | **deprecated · retires 2026-10-23** | token-based | legacy per 1024² image: $0.011 / $0.042 / $0.167 | per-image L · token rates ✗ | /deprecations |

## Google

| Model | Status | Pricing model | Price (native) | conf | Source |
|---|---|---|---|---|---|
| **Nano Banana Pro** (Gemini 3 Pro Image) | current flagship | token-based | $0.134 / image (1–2K) · $0.24 (4K). Image out $120/1M | H | ai.google.dev/gemini-api/docs/pricing |
| **Nano Banana 2** (Gemini 3.1 Flash Image) | active | token-based | $0.045 / $0.067 / $0.101 / $0.151 (0.5K/1K/2K/4K). Image out $60/1M | H | same |
| **Gemini 2.5 Flash Image** ("Nano Banana") | active (preview) | token-based | ≈ $0.039 / image (≤1024², 1,290 tok @ $30/1M) | H | same |
| **Imagen 4** | **deprecated · retires 2026-08-17** | per image (tiered) | $0.02 / $0.04 / $0.06 (Fast/Std/Ultra) | H | same |

## Black Forest Labs

| Model | Status | Pricing model | Price (native) | conf | Source |
|---|---|---|---|---|---|
| **FLUX1.1 [pro]** | active | per image (flat) | $0.04 / image | H | docs.bfl.ml/quick_start/pricing |
| **FLUX.2 [pro]** | current flagship | per megapixel (tiered) | $0.03 first MP + $0.015/addl MP. Siblings: [max] from $0.07, [klein] ~$0.014/MP, [flex] $0.05/MP | H | same |

## Independents (per-image / per-tier, primary-confirmed)

| Model | Provider | Status | Pricing model | Price (native) | conf | Source |
|---|---|---|---|---|---|---|
| **Ideogram 3.0** | Ideogram | active | per image (tiered) | $0.03 / $0.06 / $0.09 (Turbo/Default/Quality) | H | ideogram.ai/features/api-pricing |
| **Recraft V3** | Recraft | active | per image (flat) | $0.04 raster / $0.08 vector (SVG) | H | recraft.ai/docs/api-reference/pricing |
| **Nova Canvas** | Amazon | active | per image (tiered) | $0.04 std / $0.06 premium (1024²); $0.06 / $0.08 (2048²) | H | aws.amazon.com/nova/pricing |
| **Photon** | Luma | active | per image (flat) | $0.015 / image (Photon Flash $0.002) | H | docs.lumalabs.ai |
| **Grok Imagine Image** | xAI | active | per image (flat) | $0.02 / image (std) · $0.05 (quality) | H | docs.x.ai/developers/models/grok-imagine-image |
| **Seedream 4.5** | ByteDance | active | per image (flat) | $0.04 / image (flat to 4K) | H (BytePlus JS; corroborated) | docs.byteplus.com/en/docs/ModelArk |

## Credit-based

| Model | Provider | Status | Pricing model | Price (native) | conf | Source |
|---|---|---|---|---|---|---|
| **Stable Diffusion 3.5 Large** | Stability | active | credit-based (+ open weights) | 6.5 credits ≈ $0.065 (1 cr = $0.01). Siblings: 3.5 Medium ~$0.035, Large Turbo ~$0.04, Ultra ~$0.08 | M-H | platform.stability.ai/pricing |
| **Reve** | Reve | active (beta) | credit-based | 5 credits ≈ $0.0067 / image (7,500 cr / $10) | M-H | api.reve.com/console/pricing |
| **Bria** | Bria | active | per action (PAYG) | ~$0.02–$0.03 / image (Fibo $0.03, Fibo Lite $0.02) | H | bria.ai/pricing |
| **Firefly Services** | Adobe | active | credit-based (enterprise) | ~10 credits / std image (~20 for Image 4 Ultra); per-credit rate negotiated, no public per-image $ | model H · per-image ✗ | business.adobe.com/products/firefly-business |
| **Leonardo AI** | Leonardo | active | credit-based (PAYG) | billed in API credits; per-image varies by model/resolution; $5 starter credit | model H · per-image ✗ | docs.leonardo.ai |

## Not confirmable on a primary source — list without a price

| Model | Provider | Why | Honest display |
|---|---|---|---|
| **Qwen-Image** | Alibaba | Model Studio per-image rate not extractable; Alibaba's "$0.10" is an illustrative example, not the rate. fal.ai fallback $0.02/MP (L) | List (open-weights + API), pricing "not published / not verified"; note open weights (Apache 2.0) |

## Do not publish as fact (still unconfirmed)

1. **gpt-image-1 token rates** — removed from the live pricing page; the legacy per-image table is a low-confidence fallback only.
2. **gpt-image-1.5 / -mini per-image tables** — token rates are H, per-image tables M (single fetch).
3. **Qwen-Image first-party per-image price** — not extractable; do not publish "$0.03" or Alibaba's "$0.10" example.
4. **xAI "$0.07 pro" tier and the "Aurora" name** — wrong. Current model is "Grok Imagine Image", high tier $0.05.
5. **Bria "$0.04 / $0.005–$0.08" range** — stale; current is ~$0.02–$0.03/action.
6. **"Nano Banana 2 Lite"** figures — third-party only.
7. **Adobe Firefly** ~$1,000/mo minimum and ~$0.02/image — secondary only; publish as credit-based (credits-per-operation), not a per-image dollar.
8. **Reve / SD 3.5 Large** exact credit counts — well-corroborated but primary pages were gated/JS-rendered (M-H, not H).

## Representation implications

- **Five pricing-model types** appear here: per-image flat, per-image tiered, per-megapixel, token-based, credit-based — plus one row (Qwen) with **no publishable price**. The display must handle all six honestly:
  - flat/tiered/per-MP → show the native figure(s) in the cell.
  - token-based → show the provider's per-image equivalent at a stated size, mechanism on the model page.
  - credit-based → show credits + the credit→USD basis; where no per-image $ exists (Adobe, Leonardo), show the credit model, not a number.
  - no publishable price (Qwen) → "pricing not published / not verified", never a guess.
- **Deprecations are load-bearing:** gpt-image-1 (Oct 2026), Imagen 4 (Aug 2026), gpt-image-1.5/-mini (Dec 2026) are all sunsetting this year — mark them `legacy` with the retirement date, per the "complete directory incl. lifecycle" decision.
- Each priced row carries a **source** and an **as-of date** (2026-07-01), same as the per-token rows already do.
