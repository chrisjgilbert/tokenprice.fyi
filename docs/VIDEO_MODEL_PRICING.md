# Video-generation model pricing — sourced dataset

> **As of 2026-07-11.** The authoritative input for the video-generation category
> (seeds + display). Video generation is billed more heterogeneously than any
> other category on this site: per **second** of output, per **clip/generation**
> (flat or tiered), by **resolution** (480p/720p/1080p/4K), by **duration**
> (5s/10s), **with vs. without a generated audio track** (Veo 3's audio is the
> canonical case), in **credits**, or in **tokens**. There is no single
> comparable headline unit — the directory shows each model in its native shape
> with a one-word **pricing-model** label and never flattens them into one
> column. Every figure is cited and confidence-rated; anything not confirmable on
> a primary source is listed in **Do not publish as fact** at the bottom and must
> render as "not published / not verified", never a guessed number. Companion to
> `docs/IMAGE_MODEL_PRICING.md` and `docs/SPEECH_TO_TEXT_MODEL_PRICING.md` (same
> format).

## How to read this

- **Headline native price** — a clean per-second USD rate where one exists;
  otherwise a tight `price_summary`-style string that captures the tiers
  (e.g. `"$0.40/sec (720p/1080p) · $0.60/sec (4K)"`, `"$0.05/sec"`, `"credits"`,
  `"tokens"`). This is the row's displayed price string — keep it honest.
- **Pricing model** — one of five badge labels:
  - **per_second** — billed per second of generated video (Veo, Sora, Runway-effective, Wan/LTX on fal).
  - **per_video** — one flat price per clip regardless of length within limits (Hunyuan on fal, Mochi on Replicate).
  - **per_image_tiered** — a price per resolution/quality tier per clip (Pika on fal, Luma Ray 2 on fal).
  - **credit_based** — billed in credits/points; we show the credit count + the credit→USD basis (Runway native, Luma native, MiniMax Hailuo).
  - **token_based** — billed in tokens; we show the per-million-token rate + a derived per-clip equivalent with the mechanism noted (Seedance).
- **Billing basis + tiers** — the native unit and what varies it (resolution,
  duration, audio on/off), stated as a `price_detail`-style sentence.
- **Open-weight?** — where the model is open weights (Hunyuan, Wan, LTX, Mochi,
  SVD), we say **self-host $0 (own GPU) / hosted ~$X via partner** rather than
  inventing a single rate.
- `conf` = confidence: **H** primary source (the provider's own page/docs),
  **M** corroborated but the primary page is gated/JS-rendered or the figure
  comes from a hosting partner/reseller (fal, Replicate), **L** not confirmable
  on a primary source.

Two structural facts drive most of the confidence gaps below. First, several
**Chinese labs** (Kuaishou/Kling, ByteDance/Seedance, MiniMax/Hailuo) publish
their developer pricing on JS-gated consoles or in non-USD units, so the clean
per-second number usually comes from a Western hosting partner (fal.ai) and is
rated **M**. Second, the **open-weight** models have no single price at all — the
honest statement is "$0 on your own GPU, or ~$X on a partner endpoint", and the
partner rate is the only thing to cite.

## OpenAI (Sora)

Fetched directly from the developer pricing page — **H**. Sora is billed strictly
**per second of output**, tiered by resolution, with a flat **50% batch
discount** across every tier. Standard Sora-2 is 720p-only; Sora-2-Pro adds
1024p and 1080p. No separate audio charge (audio is generated inline).

| Model | Headline | Pricing model | Basis + tiers | conf | Source (as of 2026-07-11) |
|---|---|---|---|---|---|
| **Sora 2** | **$0.10/sec** (720p) · $0.05/sec batch | per_second | Per second, 720p only. Batch = 50% off. | H | developers.openai.com/api/docs/pricing · /models/sora-2 |
| **Sora 2 Pro** | **$0.30/sec (720p) · $0.50 (1024p) · $0.70 (1080p)** · batch $0.15/$0.25/$0.35 | per_second | Per second, tiered by resolution; batch = 50% off each tier. | H | developers.openai.com/api/docs/pricing |

Lifecycle: the Sora 2 / Sora 2 Pro API is widely reported to sunset **2026-09-24**
(secondary sources; not confirmed on the primary pricing page fetch — see caveats).

## Google (Veo, via Gemini API)

Fetched directly from the Gemini API pricing page — **H**. Billed **per second**,
tiered by resolution, and **audio is included in the per-second rate at every
tier** (there is no cheaper "video-only" line for Standard on the current page).
The audio-on/audio-off split that made Veo 3 famous has collapsed into
"audio included" on Veo 3.1. Veo 3.1 ships in three variants (Standard / Fast /
Lite).

| Model | Headline | Pricing model | Basis + tiers | conf | Source (as of 2026-07-11) |
|---|---|---|---|---|---|
| **Veo 3.1** (`veo-3.1-generate-preview`) | **$0.40/sec** (720p/1080p) · $0.60/sec (4K) | per_second | Per second; audio included. | H | ai.google.dev/gemini-api/docs/pricing |
| **Veo 3.1 Fast** (`veo-3.1-fast-generate-preview`) | **$0.10/sec (720p) · $0.12 (1080p) · $0.30 (4K)** | per_second | Per second; audio included. | H | same |
| **Veo 3.1 Lite** (`veo-3.1-lite-generate-preview`) | **$0.05/sec (720p) · $0.08 (1080p)** | per_second | Per second; audio included; no 4K. | H | same |
| **Veo 3** (`veo-3.0-generate-001`) | $0.40/sec (std) · Fast $0.10/$0.12/$0.30 | per_second | Per second; audio included. **Deprecated, shuts down 2026-06-30** (past). | H | same |
| **Veo 2** (`veo-2.0-generate-001`) | $0.35/sec | per_second | Per second; audio included. **Deprecated, shut down 2026-06-30** (past). | H | same |

Note on the audio story: Veo 3's original with-audio ($0.40) vs. without-audio
($0.20) split is the canonical example of audio-driven video pricing, but on the
**current** page Veo 3 and 3.1 list a single audio-included per-second rate per
tier. Keep the audio-on/off mechanism in the explainer, but the live rows are
single-rate.

## Runway (Gen-4)

Fetched directly from the API pricing docs — **H**. Runway's API is natively
**credit-based** at a fixed **1 credit = $0.01** (API credits are separate from
subscription credits), and every video model is quoted in **credits per second**,
so the effective per-second USD is exact.

| Model | Headline | Pricing model | Basis + tiers | conf | Source (as of 2026-07-11) |
|---|---|---|---|---|---|
| **Gen-4 Turbo** | **$0.05/sec** (5 credits/sec) | credit_based → per_second | 5 cr/sec × $0.01. | H | docs.dev.runwayml.com/guides/pricing |
| **Gen-4.5** | **$0.12/sec** (12 credits/sec) | credit_based → per_second | 12 cr/sec × $0.01. | H | same |
| **Gen-3 Alpha Turbo** | $0.05/sec (5 credits/sec) | credit_based → per_second | 5 cr/sec × $0.01. **Deprecated, sunsets 2026-07-30.** | H | same |

The same docs page also lists partner models billed through Runway credits
(reseller rates, not the model's native price): **Veo 3.1** 40 cr/sec ($0.40/sec,
with audio), **Seedance 2.0** 36 cr/sec ($0.36/sec, 480p/720p), **Aleph 2.0**
28 cr/sec min. Plain **Gen-4** (non-Turbo) was historically 12 credits/sec
($0.12/sec) but is not on the current docs fetch — see caveats.

## Kuaishou (Kling)

The official developer console (`kling.ai/dev/pricing`, redirected from
`klingai.com`) is **JS-gated** and returned no figures on fetch. The clean
per-second number comes from the **fal.ai** hosted endpoint — **M**. Kling on fal
is priced as a **base 5-second clip + per-additional-second**, which works out to
a flat per-second rate.

| Model | Headline | Pricing model | Basis + tiers | conf | Source (as of 2026-07-11) |
|---|---|---|---|---|---|
| **Kling 2.5 Turbo Pro** | **$0.07/sec** (fal: $0.35 / 5s + $0.07/addl sec) | per_video → per_second | $0.35 base 5s, +$0.07 each further second (→ flat $0.07/sec). | M | fal.ai/models/fal-ai/kling-video/v2.5-turbo/pro/text-to-video |
| **Kling (range, all versions/modes)** | ~$0.08–$0.42/sec | per_second | Varies by version, Standard vs. Pro mode, duration, audio. | L | costbench.com/software/ai-media-apis/kling-api (aggregator) |

Official Kling API pricing (native credit/"inspiration" units) is **not**
primary-confirmed at current rates — publish the fal per-second (M), not an
official figure.

## Pika

`pika.art` sells **credit-based subscriptions** and does not publish a public
per-call API rate; the developer price comes from **fal.ai** — **M**. Billed
per resolution tier per clip; effective per-second is derivable.

| Model | Headline | Pricing model | Basis + tiers | conf | Source (as of 2026-07-11) |
|---|---|---|---|---|---|
| **Pika 2.2** | **$0.20/clip (720p) · ~$0.45 (1080p)** (5s) | per_image_tiered | Per clip by resolution; 1080p ≈ 2.25× the 720p tier. | M | fal.ai/models/fal-ai/pika/v2.2/text-to-video |
| **Pika 2.2 Pikaframes** | $0.04/sec (720p) · $0.06/sec (1080p) | per_second | Keyframe interpolation, per second by resolution. | M | fal.ai/models/fal-ai/pika/v2.2/pikaframes |

## Luma (Dream Machine / Ray)

The official Luma pricing page was fetched — **H that the credit-per-second
figures appear** — but the page does **not** print the API credit→USD rate
(API is metered in dollars, billed separately from Dream Machine subscription
credits), so a native USD/sec can't be derived from the primary page. The clean
per-second USD comes from **fal.ai** — **M**. Current flagship is **Ray3.14**
(native 1080p, launched 2026-01-26); Ray 2 remains the affordable option.

| Model | Headline | Pricing model | Basis + tiers | conf | Source (as of 2026-07-11) |
|---|---|---|---|---|---|
| **Ray 2** | **$0.10/sec** (fal: $0.50 / 5s, 720p) | per_image_tiered → per_second | fal: $0.50/5s at 720p; 1080p ≈ 4× ($2.00/clip); +~$1 for 4K upscale. | M | fal.ai/models/fal-ai/luma-dream-machine/ray-2 |
| **Ray3.14** (flagship) | **credits** — Draft 4 · 540p 10 · 720p 20 · 1080p 80 (credits/sec) | credit_based | Native credits/sec by resolution; HDR ×2, HDR+EXR ×3. Credit→USD not on page. | credits H · USD ✗ | lumalabs.ai/pricing |
| **Ray3.2** | **credits** — Draft 20 · 540p 50 · 720p 100 · 1080p 400 (credits / 5s) | credit_based | Native credits per 5s by resolution; HDR/EXR multipliers. Credit→USD not on page. | credits H · USD ✗ | lumalabs.ai/pricing |

Publish Ray 2 at the fal per-second (M). For Ray3.x, publish the native
credits-per-second (H) and mark the USD as not-derivable until the API credit
rate is confirmed.

## MiniMax (Hailuo)

Fetched directly from the MiniMax video pricing docs — **H that the video-points
deductions appear**. Hailuo is natively **credit-based** ("video points"), billed
**per generation** by resolution × duration. The cheapest point package is
**$1,000 = 3,760 points ⇒ ≈ $0.266/point** (larger packages drop it, e.g.
Business $6,000 = 26,780 pts ⇒ ≈ $0.224/point). Per-clip USD below is derived at
the $0.266/point Standard rate — **M** (moves with package tier).

| Model | Headline | Pricing model | Basis + tiers | conf | Source (as of 2026-07-11) |
|---|---|---|---|---|---|
| **Hailuo 2.3** | **~$0.27/clip (768p 6s) · ~$0.53 (1080p 6s)** | credit_based | 1 pt (768p/6s), 2 pt (768p/10s or 1080p/6s) × ~$0.266/pt. | points H · USD M | platform.minimax.io/docs/guides/pricing-video |
| **Hailuo 2.3 Fast** | **~$0.19/clip (768p 6s) · ~$0.35 (1080p 6s)** | credit_based | 0.7 pt (768p/6s), 1.1 pt (768p/10s), 1.3 pt (1080p/6s) × ~$0.266/pt. | points H · USD M | same |
| **Hailuo 02** | **~$0.08/clip (512p 6s)** up to ~$0.53 (1080p 6s) | credit_based | 0.3 pt (512p/6s), 0.5 pt (512p/10s), 1–2 pt (768p/1080p). | points H · USD M | same |

Derived per-clip PAYG range (~$0.08–$0.53) matches MiniMax's own PAYG API band
(~$0.19–$0.56/clip) reported by secondary sources.

## ByteDance (Seedance)

Fetched from the BytePlus ModelArk model doc — **H** on the per-token rate.
Seedance is natively **token-based**: tokens scale with resolution × fps ×
duration, so cost rises with quality and length. The primary doc prints the
rate but not the token-count formula, so the per-clip USD is a **derived
estimate** — flag it.

| Model | Headline | Pricing model | Basis + tiers | conf | Source (as of 2026-07-11) |
|---|---|---|---|---|---|
| **Seedance 1.0 Pro** | **$2.50 / 1M tokens** (≈ $0.6–$0.75 / 5s 1080p, derived) | token_based | Per-token; tokens ≈ resolution × fps × duration. Same rate T2V and I2V. | rate H · per-clip M | docs.byteplus.com/en/docs/ModelArk/1587798 |

Versioning is in flux: secondary sources reference newer **Seedance 1.5 Pro** as
the live model and **Seedance 2.0** resource-pack rates (from ~$4.3–$7.7 / 1M
tokens, 720p/1080p) — those are **not** on the primary doc fetched and go in the
caveats. Publish the confirmed **1.0 Pro $2.50/1M** as the token-based rate.

## Meta (Muse Video)

Muse Video, built on the same pretraining base as Muse Image, is Meta
Superintelligence Labs' first video generation model — native audio support,
"coming soon to creators and in Meta AI" per the launch post. **H that no
public developer API exists** (as of 2026-07-14): it's positioned as a
consumer feature inside Meta's own apps, not a metered API product, so there's
no rate to publish.

| Model | Headline | Pricing model | Basis + tiers | conf | Source (as of 2026-07-14) |
|---|---|---|---|---|---|
| **Muse Video** | no public API | — | Consumer feature only ("coming soon to creators and Meta AI"); no developer API, no rate | no-API H | ai.meta.com/blog/introducing-muse-image-muse-video-msl |

## Open-weight models (self-host $0 / hosted via partner)

These have **no single price**: run them on your own GPU for the cost of compute
($0 in license), or pay a hosting partner (fal.ai, Replicate) per generation. We
cite the partner rate and state the license honestly.

| Model | Provider | Open weights | Hosted rate (partner) | Pricing model | conf | Source (as of 2026-07-11) |
|---|---|---|---|---|---|---|
| **Hunyuan Video** | Tencent | Yes (open, free for commercial use) | **$0.40 / video** on fal (Pro mode 2× = $0.80); all res (480/580/720p) same flat rate | per_video | rate H (fal) · open-weight H | fal.ai/models/fal-ai/hunyuan-video |
| **Wan 2.5** | Alibaba | Yes (open weights) | **$0.05/sec (480p) · $0.10 (720p) · $0.15 (1080p)** on fal | per_second | rate M (fal, from listing) · open-weight H | fal.ai/models/fal-ai/wan-25-preview/text-to-video |
| **Wan 2.2** | Alibaba | Yes (open weights) | **$0.04/sec (480p) · $0.06 (580p) · $0.08 (720p)** on fal | per_second | rate M (fal) · open-weight H | fal.ai/models/fal-ai/wan/v2.2-a14b/text-to-video |
| **LTX-2 / LTXV** | Lightricks | Yes (open weights) | **Pro $0.06/sec (1080p) · $0.12 (1440p) · $0.24 (4K)**; Fast $0.04/$0.08/$0.16 | per_second | rate M (fal) · open-weight H | fal.ai/models/fal-ai/ltx-2/text-to-video · /ltx-2.3 |
| **Mochi 1** | Genmo | Yes (Apache 2.0; ~60GB VRAM single-GPU) | **~$0.42 / run** on Replicate (≈2 runs/$1) | per_video | rate M (Replicate) · open-weight H | replicate.com/genmoai/mochi-1 |
| **Stable Video Diffusion** | Stability | Yes (SVD Community License; weights on HF) | **No official API** (removed); third-party only, per-use | per_video | official-API ✗ · open-weight H | platform.stability.ai/pricing · huggingface.co (weights) |

Self-host reality check: Hunyuan, Wan, LTX, Mochi, and SVD are all downloadable
and run at **$0 license** on your own hardware — the only cost is GPU time. The
partner rates above are the convenience price, not the model's "price".

## Headline per-second leaderboard (clean rates only, orientation)

Cheapest → dearest. **Units differ** — some of these are per-second of a
720p clip with audio, some are 1080p without, some are effective rates derived
from a base-clip-plus-per-second model. Read the rows before comparing.

| $/sec | Model | Tier / note | conf |
|---|---|---|---|
| $0.04 | Wan 2.2 (fal) · LTX-2 Fast (fal) | 480p / 1080p-fast, open-weight | M |
| $0.05 | **Veo 3.1 Lite** (720p) · **Sora 2** batch (720p) · **Runway Gen-4 Turbo** · Wan 2.5 (fal, 480p) | mixed | H / H / H / M |
| $0.06 | LTX-2 Pro (fal, 1080p) | open-weight | M |
| $0.07 | Kling 2.5 Turbo Pro (fal, effective) | reseller | M |
| $0.08 | Veo 3.1 Lite (1080p) · Wan 2.2 (fal, 720p) | — | H / M |
| $0.10 | **Sora 2** (720p) · **Veo 3.1 Fast** (720p) · **Luma Ray 2** (fal, 720p) · Wan 2.5 (fal, 720p) | — | H / H / M / M |
| $0.12 | **Veo 3.1 Fast** (1080p) · **Runway Gen-4.5** | — | H / H |
| $0.15 | Wan 2.5 (fal, 1080p) | open-weight | M |
| $0.30 | **Sora 2 Pro** (720p) · Veo 3.1 Fast (4K) | — | H |
| $0.40 | **Veo 3.1** (720p/1080p, audio incl.) | flagship | H |
| $0.50 | Sora 2 Pro (1024p) | — | H |
| $0.60 | Veo 3.1 (4K) | — | H |
| $0.70 | Sora 2 Pro (1080p) | top tier | H |

Not on this leaderboard because they aren't natively per-second: Hunyuan
($0.40/video flat), Pika ($0.20–0.45/clip tiered), MiniMax Hailuo (per-clip
video-points), Seedance ($2.50/1M tokens), Mochi ($0.42/run), Luma Ray3.x
(native credits, USD not derivable).

## Which model bills how (native unit)

- **Natively per-second (bill == seconds of output):** OpenAI Sora 2 / Sora 2
  Pro; Google Veo 2 / 3 / 3.1 (all variants); Wan 2.2 / 2.5 and LTX-2 as served
  on fal. These have a clean per-second rate; resolution tiers multiply it.
- **Natively credit-based (credits/points → per-second or per-clip):** Runway
  (credits/sec at 1 cr = $0.01 — cleanly per-second); Luma Ray3.x (credits/sec
  by resolution, but API credit→USD not published); MiniMax Hailuo (video-points
  per generation).
- **Per-clip flat or tiered:** Hunyuan Video ($0.40/video flat, on fal);
  Pika 2.2 (per resolution tier per clip); Mochi 1 (~$0.42/run on Replicate);
  Kling on fal (base 5s + per-additional-second, i.e. flat-per-second in
  disguise).
- **Token-billed:** ByteDance Seedance ($2.50/1M tokens; tokens ≈ resolution ×
  fps × duration). The per-clip USD must be derived and flagged, never shown as
  a flat price.
- **Open-weight (self-host $0 / hosted ~$X):** Tencent Hunyuan Video, Alibaba
  Wan 2.x, Lightricks LTX/LTXV, Genmo Mochi 1, Stability Stable Video Diffusion.
  Show "$0 own GPU / ~$X via partner", never a single invented rate.

## Do not publish as fact (unconfirmed / caveated)

1. **Sora 2 / Sora 2 Pro sunset date (2026-09-24)** — widely reported by
   secondary sources but not on the primary pricing-page fetch. Publish the
   prices (H); mark the retirement date as unconfirmed until seen on OpenAI's own
   deprecations page.
2. **Kling official native pricing** — `kling.ai/dev/pricing` is JS-gated and
   returned no figures. Publish the **fal.ai** per-second ($0.07/sec, Kling 2.5
   Turbo Pro) as **M**; do **not** publish an "official" Kling per-second or the
   aggregator $0.08–$0.42/sec band as fact.
3. **Runway plain Gen-4 (non-Turbo)** — historically 12 credits/sec ($0.12/sec)
   but not on the current API docs fetch (which lists Gen-4 Turbo and Gen-4.5).
   Do not publish a plain-Gen-4 rate until re-confirmed; Gen-4 Turbo and Gen-4.5
   are H.
4. **Luma Ray 2 / Ray3.x USD per second** — the primary Luma page prints
   credits/sec (H) but **not** the API credit→USD rate, so no native USD/sec is
   derivable. Ray 2's $0.10/sec is the **fal.ai** hosted figure (M). Do not
   convert Ray3.x credits to USD without the confirmed API credit price.
5. **MiniMax Hailuo per-clip USD** — the docs give **video-points** deductions
   (H); the USD figures are **derived** at the cheapest Standard package rate
   (~$0.266/point) and shift with package tier (down to ~$0.224/point). Publish
   points as H, per-clip USD as M with the basis stated.
6. **Seedance per-clip USD and version** — $2.50/1M tokens for **Seedance 1.0
   Pro** is primary (H); the ~$0.6–$0.75 per-5s-1080p clip is a **derived
   estimate** (M) because the doc omits the token-count formula. Newer **Seedance
   1.5 Pro** (reported live) and **Seedance 2.0** resource-pack rates
   ($4.3–$7.7/1M tokens) are secondary-only — do not publish as current.
7. **Wan / LTX fal per-second rates** — from fal listing text via search, not a
   direct fetch of each model's price widget (M). The open-weight status is H;
   the exact fal per-second is M until re-fetched from each model page.
8. **Mochi Replicate ~$0.42/run** — Replicate compute-time price, varies with
   inputs; not a fixed per-clip rate. Open-weight (Apache 2.0) is H.
9. **Stable Video Diffusion hosted rate** — no official Stability API (removed);
   any per-use figure is third-party (Segmind etc.) and **L**. Publish as
   open-weight, "no official API", self-host $0.
10. **Veo audio-on/off split** — the famous Veo 3 "$0.40 with audio / $0.20
    without" is not the current live structure; the page now lists a single
    audio-included per-second rate per tier. Keep the mechanism in the explainer,
    but publish the single-rate rows.
