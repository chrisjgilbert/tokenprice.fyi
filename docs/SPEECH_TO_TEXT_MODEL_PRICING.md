# Speech-to-text (transcription) model pricing — sourced dataset

> **As of 2026-07-06.** The authoritative input for the speech-to-text
> (transcription) category (seeds + display). Transcription is billed against
> **audio duration**, so the comparable headline unit here is **USD per minute of
> audio**. Providers publish in different native units (per-second, per-minute,
> per-hour, or per-token); every row states the native basis and the per-minute
> figure derived from it. Every figure is cited and confidence-rated; anything
> not confirmable on a primary source is listed in **Do not publish as fact** at
> the bottom and must render as "not published / not verified", never a guessed
> number. Companion to `docs/EMBEDDING_MODEL_PRICING.md` and
> `docs/IMAGE_MODEL_PRICING.md` (same format).

## How to read this

- **$/min** — USD per minute of audio, standard pay-as-you-go tier. This is the
  headline, sortable number. Where a model has batch/streaming or multiple
  quality tiers, the headline is the standard pay-as-you-go rate for its primary
  mode and the other tiers are noted in the row or below the table.
- **Native basis** — the unit the provider actually bills in, before conversion:
  per-second, per-minute, per-hour, or token-based. Conversions used:
  `$/hr ÷ 60 = $/min`; `$/15s × 4 = $/min`.
- **Mode** — **batch** (async / pre-recorded file) vs **stream** (real-time /
  WebSocket). Streaming rates are usually higher and, for some providers
  (AssemblyAI), billed on session wall-clock rather than audio sent.
- **Token-billed** models (OpenAI's `gpt-4o-transcribe` family) do not publish a
  per-minute rate as the bill; they meter audio-input and text-output tokens. The
  $/min shown is **OpenAI's own published per-minute estimate**, and these rows
  are flagged. See the token-billed note at the bottom.
- `conf` = confidence: **H** primary source (provider's own page/docs), **M**
  corroborated across sources but the primary pricing page is gated/JS-rendered
  or reseller-only, **L** not confirmable on a primary source.

Most billing is metered per second and rounded to the second (Deepgram, Azure,
ElevenLabs); Google rounds up to 15-second chunks; Groq bills a 10-second
minimum per request. These rounding rules matter for short clips and are noted
per provider.

## OpenAI

`whisper-1` is not on the current developer pricing page (the page now leads with
the `gpt-4o-transcribe` family); its $0.006/min rate is long-standing and widely
published — treat as **M**. The `gpt-4o-transcribe` / `-mini` rows are the exact
per-1M-token rates from the primary pricing page, with OpenAI's **own** per-minute
estimate as the headline (**H** for both the token rates and the estimate).

| Model | $/min | Native basis | Mode | conf | Source (as of 2026-07-06) |
|---|---|---|---|---|---|
| **gpt-4o-transcribe** | **$0.006** (OpenAI est.) | token-based: $2.50 /1M audio-input, $10.00 /1M text-output | batch + stream | H | developers.openai.com/api/docs/pricing · /models/gpt-4o-transcribe |
| **gpt-4o-mini-transcribe** | **$0.003** (OpenAI est.) | token-based: $1.25 /1M input, $5.00 /1M output | batch + stream | H | developers.openai.com/api/docs/pricing |
| **gpt-realtime-whisper** | **$0.017** | per-minute (output) | stream (realtime) | H | developers.openai.com/api/docs/pricing |
| **whisper-1** (legacy) | **$0.006** | per-minute (billed per second) | batch | M | rate long-published; not on current dev pricing page |

Note: for the token-billed `gpt-4o-transcribe` family, $0.006 and $0.003/min are
the figures OpenAI itself prints next to the model as an "estimated cost". The
actual bill is the token meter above; the per-minute estimate assumes typical
speech token density. Flag as token-billed on display (see bottom).

## Deepgram

Fetched directly from the pricing page (**H** that these numbers appear on the
page). One caveat lowers confidence on the batch/stream split to **M**: the live
page currently shows Nova-3 **streaming cheaper than pre-recorded** (mono
$0.0048 stream vs $0.0077 batch), which inverts the historical Deepgram structure
and inverts several 2025-era aggregators (which cite Nova batch ≈ $0.0043/min,
stream ≈ $0.0077/min). Numbers below are as the page reads on this date; re-verify
the mode labels at seed time. All Deepgram billing is per second. Nova-2 (and
Enhanced/Base) remain available as legacy but are no longer priced on the pricing
page.

| Model | $/min | Native basis | Mode | conf | Source (as of 2026-07-06) |
|---|---|---|---|---|---|
| **Nova-3 (monolingual)** | **$0.0077** batch · $0.0048 stream | per-minute (per-second billed), PAYG | batch + stream | price H · mode M | deepgram.com/pricing |
| **Nova-3 (multilingual)** | **$0.0092** batch · $0.0058 stream | per-minute, PAYG | batch + stream | price H · mode M | deepgram.com/pricing |
| **Flux (English, streaming ASR)** | **$0.0065** stream · $0.0077 batch | per-minute, PAYG | stream (+ batch) | price H · mode M | deepgram.com/pricing |
| **Flux (multilingual)** | **$0.0078** stream | per-minute, PAYG | stream | price H · mode M | deepgram.com/pricing |
| **Nova-2 / Enhanced / Base** (legacy) | not on pricing page | per-minute | batch + stream | L | deepgram.com/pricing (listed as "older models", unpriced) |

Growth plan (annual prepay) discounts each rate ~15–20% (e.g. Nova-3 mono
stream $0.0048 → $0.0042).

## AssemblyAI

Primary pricing page fetched directly — **H**. "Nano" and "Best" as model
identifiers are deprecated (`nano` previously routed to Universal-2, `best` to the
Pro model); SLAM-1 is deprecated with a migration notice. Async is billed on
audio duration; **streaming is billed on WebSocket session wall-clock** (open-to-
close, including idle), so its effective $/min can exceed the base rate.

| Model | $/min | Native basis | Mode | conf | Source (as of 2026-07-06) |
|---|---|---|---|---|---|
| **Universal-3.5 Pro** | **$0.0035** | per-hour ($0.21/hr) | batch (async) | H | assemblyai.com/pricing |
| **Universal-2** | **$0.0025** | per-hour ($0.15/hr) | batch (async) | H | assemblyai.com/pricing |
| **Universal-Streaming (English / multilingual)** | **$0.0025** | per-hour ($0.15/hr), session-billed | stream | H | assemblyai.com/pricing |
| **Universal-3.5 Pro Realtime** | **$0.0075** | per-hour ($0.45/hr base), session-billed | stream | H | assemblyai.com/pricing |
| **Nano** (deprecated) | routes to Universal-2 ($0.0025) | per-hour | batch | M | assemblyai.com/blog/introducing-nano (historical); now deprecated |
| **SLAM-1** (deprecated) | migrate to Universal-3 Pro | — | — | H | assemblyai.com/pricing |

Add-ons (diarization, sentiment, medical mode +$0.15/hr, etc.) stack on the base
rate.

## Google Cloud Speech-to-Text (v2 / Chirp)

The primary pricing page is JS-gated and did not render dollar figures on fetch;
the rates below are corroborated by Google's own V2 launch blog and docs plus
aggregators — treat as **M**. Chirp / Chirp 2 / Chirp 3 are priced at the same
v2 recognition rate (not a separate premium). Billing rounds **up to 15-second
increments**. Free tier: 60 min/month.

| Model / tier | $/min | Native basis | Mode | conf | Source (as of 2026-07-06) |
|---|---|---|---|---|---|
| **v2 standard (incl. Chirp/Chirp 2/Chirp 3)** | **$0.016** | per-15s ($0.004/15s) | batch + stream (real-time) | M | cloud.google.com/speech-to-text/pricing · cloud.google.com/blog Speech-to-Text V2 API |
| **v2 Dynamic Batch** (≤24h turnaround) | **~$0.004** | per-15s, 75% off standard | batch (deferred) | M | same (blog: "75% lower than Standard") |

## Azure AI Speech (Speech-to-Text)

The Azure pricing page renders prices client-side (shows `$-` placeholders on
fetch), so figures are corroborated via Microsoft Q&A + aggregators — **M**.
Billing is per second. Free tier: 5 audio hours/month.

| Model / tier | $/min | Native basis | Mode | conf | Source (as of 2026-07-06) |
|---|---|---|---|---|---|
| **Standard real-time** | **$0.0167** | per-hour ($1.00/hr) | stream (real-time) | M | azure.microsoft.com/pricing/details/speech · MS Q&A |
| **Fast transcription** | **$0.006** | per-hour ($0.36/hr) | batch (fast) | M | same |
| **Batch transcription** | **$0.003** | per-hour ($0.18/hr) | batch | M | same |

Enhanced real-time add-ons (diarization, language ID, pronunciation assessment)
add ~$0.30/hr each; included free in batch. Commitment tier (50k hr/mo) drops
standard to ~$0.0083/min ($0.50/hr).

## Speechmatics

The pricing page is JS-gated; Speechmatics' current lead model is **Melia**
(multilingual), with the page stating batch **"from $0.129/hr"** for the Pro
tier — that specific figure is corroborated across the page and aggregators
(**M**). Older Standard/Enhanced per-hour rates (batch ~$0.80–$1.04/hr, real-time
~$1.04–$1.35/hr) are from 2025-era aggregators and may be superseded by the Melia
per-hour model; do not publish them as current. Free tier: 8 hours/month.

| Model / tier | $/min | Native basis | Mode | conf | Source (as of 2026-07-06) |
|---|---|---|---|---|---|
| **Melia — Pro batch** | **~$0.00215** ("from") | per-hour (from $0.129/hr) | batch | M | speechmatics.com/pricing |
| **Melia — real-time** | not primary-confirmed | per-hour | stream | L | speechmatics.com/pricing (JS-gated) |
| Standard / Enhanced (legacy split) | see caveat — not published as current | per-hour | batch + stream | L | 2025 aggregators only |

## Gladia

Primary pricing page fetched directly — **H**. Current model is **Solaria-3**;
features (diarization, sentiment, custom vocab) are bundled into the per-hour
rate. Free tier: 10 hours/month.

| Model / tier | $/min | Native basis | Mode | conf | Source (as of 2026-07-06) |
|---|---|---|---|---|---|
| **Solaria — async (Starter/PAYG)** | **$0.0102** | per-hour ($0.61/hr) | batch (async) | H | gladia.io/pricing |
| **Solaria — real-time (Starter/PAYG)** | **$0.0125** | per-hour ($0.75/hr) | stream | H | gladia.io/pricing |
| Growth (commitment) | async ~$0.0033 · real-time ~$0.0042 | per-hour ($0.20 / $0.25/hr) | batch + stream | H | gladia.io/pricing |

## Rev AI

Primary pricing page fetched directly — **H**. Current model is **Reverb**
(with a cheaper **Reverb turbo**); Whisper-based models are also offered per
minute. Human transcription ($1.99/min) is excluded as it is not an API/ASR
model.

| Model | $/min | Native basis | Mode | conf | Source (as of 2026-07-06) |
|---|---|---|---|---|---|
| **Reverb** | **$0.0033** | per-hour ($0.20/hr) | batch (async) | H | rev.ai/pricing |
| **Reverb turbo** | **$0.00167** | per-hour ($0.10/hr) | batch (async) | H | rev.ai/pricing |
| **Whisper Fusion** | **$0.005** | per-minute | batch | H | rev.ai/pricing |
| **Whisper Large** | **$0.005** | per-minute | batch | H | rev.ai/pricing |

Streaming/real-time rate not separately printed on the page fetch — mark
streaming **L** until confirmed.

## Groq

Primary pricing page fetched directly — **H**. Open-weight Whisper models served
on GroqCloud, priced per hour of audio; **10-second minimum billed per request**,
which dominates cost for very short clips.

| Model | $/min | Native basis | Mode | conf | Source (as of 2026-07-06) |
|---|---|---|---|---|---|
| **whisper-large-v3** | **$0.00185** | per-hour ($0.111/hr) | batch | H | groq.com/pricing · console.groq.com/docs/model/whisper-large-v3 |
| **whisper-large-v3-turbo** | **$0.000667** | per-hour ($0.04/hr) | batch | H | groq.com/pricing · console.groq.com/docs/model/whisper-large-v3-turbo |

## ElevenLabs (Scribe)

Primary API pricing page fetched directly — **H**. ElevenLabs states STT is
"billed per audio minute"; rates are printed per hour. Add-ons: entity detection
+$0.07/hr, keyterm prompting +$0.05/hr.

| Model | $/min | Native basis | Mode | conf | Source (as of 2026-07-06) |
|---|---|---|---|---|---|
| **Scribe (v1 / v2)** | **$0.00367** | per-hour ($0.22/hr), per-minute billed | batch | H | elevenlabs.io/pricing/api |
| **Scribe v2 Realtime** | **$0.0065** | per-hour ($0.39/hr) | stream (real-time) | H | elevenlabs.io/pricing/api · elevenlabs.io/realtime-speech-to-text |

## Headline $/min leaderboard (standard PAYG, primary mode)

Cheapest → dearest, for orientation only (modes/units differ — read the rows):

| $/min | Model | conf |
|---|---|---|
| $0.000667 | Groq whisper-large-v3-turbo | H |
| $0.00167 | Rev AI Reverb turbo | H |
| $0.00185 | Groq whisper-large-v3 | H |
| $0.00215 | Speechmatics Melia (Pro batch, "from") | M |
| $0.0025 | AssemblyAI Universal-2 | H |
| $0.003 | OpenAI gpt-4o-mini-transcribe (token-billed est.) · Azure batch | H · M |
| $0.0033 | Rev AI Reverb | H |
| $0.0035 | AssemblyAI Universal-3.5 Pro | H |
| $0.00367 | ElevenLabs Scribe | H |
| $0.006 | OpenAI whisper-1 · gpt-4o-transcribe (token est.) · Azure fast | M · H · M |
| $0.0077 | Deepgram Nova-3 mono (batch, page-read) | M |
| $0.0102 | Gladia Solaria async | H |
| $0.016 | Google STT v2 standard (Chirp) | M |
| $0.0167 | Azure standard real-time | M |
| $0.017 | OpenAI gpt-realtime-whisper | H |

## Token-billed vs natively per-minute

- **Token-billed (need a per-minute-equivalent computation, and it must be
  flagged):** OpenAI `gpt-4o-transcribe` and `gpt-4o-mini-transcribe`. These meter
  audio-input tokens + text-output tokens; the $/min shown is OpenAI's own
  published estimate ($0.006 and $0.003/min respectively), which assumes typical
  speech token density. Display the mechanism, not just the number.
- **Natively per-minute / per-second (bill == audio duration):** OpenAI
  `whisper-1` and `gpt-realtime-whisper`, all of Deepgram, AssemblyAI, Gladia,
  Rev AI, ElevenLabs Scribe.
- **Natively per-hour (converted to per-minute here):** Groq, AssemblyAI (quoted
  per hour), Azure, Speechmatics, Gladia, Rev AI, ElevenLabs — all divide-by-60.
- **Per-15-second, rounded up (converted to per-minute):** Google Cloud
  Speech-to-Text v2 ($0.004/15s → $0.016/min).

## Do not publish as fact (unconfirmed / caveated)

1. **Deepgram batch-vs-streaming assignment** — the live pricing page reads
   Nova-3 monolingual streaming $0.0048/min *cheaper* than pre-recorded
   $0.0077/min, inverting Deepgram's historical structure and 2025 aggregators
   (which cite batch ≈ $0.0043, stream ≈ $0.0077). The numbers are on the page
   (price H) but confirm the mode labels before publishing the split as fact.
2. **Deepgram Nova-2 / Enhanced / Base rates** — listed as available "older
   models" but no longer priced on the pricing page; do not publish a Nova-2
   number.
3. **Google STT v2 rates ($0.016/min standard, ~$0.004/min dynamic batch)** —
   primary pricing page is JS-gated; corroborated by Google's V2 launch blog +
   docs. Publish as **M**. The exact Dynamic Batch figure is derived from Google's
   "75% lower than Standard" statement, not a printed per-minute number.
4. **Azure rates ($1.00 / $0.36 / $0.18 per hr)** — primary page renders prices
   client-side ($- on fetch); corroborated via Microsoft Q&A + aggregators.
   Publish as **M**.
5. **Speechmatics** — only the Melia Pro batch "from $0.129/hr" figure is
   corroborated (M). Real-time Melia and any Standard/Enhanced split are **not**
   primary-confirmed at current prices; the legacy $0.80–$1.35/hr figures are
   2025-era aggregator data and may be superseded — do not publish as current.
6. **Rev AI streaming/real-time rate** — the page fetch showed only async Reverb
   / Reverb turbo and per-minute Whisper models; a distinct streaming rate was
   not confirmed (L).
7. **OpenAI `whisper-1` $0.006/min** — long-published and stable, but no longer
   on the current developer pricing page (superseded by the `gpt-4o-transcribe`
   family); publish as **M**, marked legacy.
8. **OpenAI `gpt-4o-transcribe` family per-minute figures** — these are OpenAI's
   *estimates*, not the metered bill (which is token-based). Always render with
   the token mechanism and the "estimate" caveat; never present $0.006/$0.003 as a
   flat per-minute price.
</content>
</invoke>
