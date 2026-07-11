# Text-to-speech (speech synthesis) model pricing — sourced dataset

> **As of 2026-07-11.** The authoritative input for the text-to-speech (TTS)
> category (seeds + display). TTS is billed predominantly against **input text
> characters**, so the comparable headline unit here is **USD per 1M characters**
> of input text. Providers publish in different native units (per character, per
> 1,000 characters, per 1M characters, per credit, or per token); every row
> states the native basis and the per-1M-character figure derived from it. Every
> figure is cited and confidence-rated; anything not confirmable on a primary
> source is listed in **Do not publish as fact** at the bottom and must render as
> "not published / not verified", never a guessed number. Companion to
> `docs/SPEECH_TO_TEXT_MODEL_PRICING.md`, `docs/EMBEDDING_MODEL_PRICING.md` and
> `docs/IMAGE_MODEL_PRICING.md` (same format).

## How to read this

- **$/1M chars** — USD per 1M input characters, standard pay-as-you-go rate for
  the model's most-common neural tier. This is the headline, sortable number.
  Where a provider tiers by voice quality, the headline is the standard neural
  tier and the other tiers are named in the row or below the table.
- **Native basis** — the unit the provider actually bills in, before conversion:
  per character, per 1,000 characters, per 1M characters, per credit, or
  token-based. Conversions used: `$/1K chars × 1000 = $/1M chars`
  (e.g. `$0.030/1K → $30/1M`); a $/1M-char figure passes through unchanged;
  `credits ÷ price × 1M = $/1M chars` at the stated credit→character basis.
- **Tier** — most providers tier by voice quality (Standard vs
  Neural / WaveNet / Studio / Generative / HD / Chirp 3 HD; ElevenLabs Flash /
  Turbo vs Multilingual). The headline is the standard/most-common neural tier;
  premium tiers are listed alongside.
- **Real-time / streaming vs batch** — for TTS this rarely changes the price
  (unlike STT). Deepgram, ElevenLabs, Google and Azure charge the same per
  character whether streamed or synthesized to a file; where a mode difference
  exists it is noted.
- **Token-billed** models (OpenAI's `gpt-4o-mini-tts`) do not publish a
  per-character rate as the bill; they meter text-input and audio-output tokens.
  Any $/1M-char figure for them is a computed estimate at a stated assumption and
  is flagged. See the token-billed note at the bottom.
- `conf` = confidence: **H** primary source (provider's own page/docs), **M**
  corroborated across sources but the primary pricing page is gated/JS-rendered
  or only a reseller has the number, **L** not confirmable on a primary source.

Most providers bill per character of **input text** (not output audio), so cost
is deterministic from the text length. ElevenLabs and Cartesia bill in
**credits** that map to characters (ElevenLabs: 1 credit/char Multilingual,
0.5 credit/char Flash/Turbo; Cartesia: 1 credit/char for Sonic). SSML tags and,
on some providers, whitespace count toward the character total.

## OpenAI

`tts-1` and `tts-1-hd` rates were fetched directly from their model pages and are
printed there as an explicit per-1M-character price — **H**. `gpt-4o-mini-tts` is
**token-billed** (text-input + audio-output tokens); its model page prints the
token rates but **no** per-character or per-minute estimate, so any $/1M-char
figure is a computed estimate and is flagged.

| Model | $/1M chars | Native basis | Tier | conf | Source (as of 2026-07-11) |
|---|---|---|---|---|---|
| **tts-1** | **$15.00** | per-1M-characters ($15.00/1M printed) | standard | H | developers.openai.com/api/docs/models/tts-1 |
| **tts-1-hd** | **$30.00** | per-1M-characters ($30.00/1M printed) | HD | H | developers.openai.com/api/docs/models/tts-1-hd |
| **gpt-4o-mini-tts** | **~$15–17** (estimate, flagged) | token-based: $0.60/1M text-input tokens + $12.00/1M audio-output tokens | steerable neural | H (token rates) · L (char estimate) | developers.openai.com/api/docs/models/gpt-4o-mini-tts |

Note: for `gpt-4o-mini-tts` the actual bill is the token meter above (text input
is negligible at ~$0.15/1M chars assuming ~4 chars/token; audio output dominates
at $12/1M audio tokens). The ~$15–17/1M-char figure assumes OpenAI's commonly
cited ~$0.015/min of generated audio at ~900 spoken chars/min; OpenAI does **not**
print this number on the page, so treat it as an estimate only and flag it on
display (see token-billed note).

## ElevenLabs

API pricing page fetched directly — **H**. ElevenLabs bills in **credits**;
Multilingual v2/v3 consume 1 credit/char, Flash v2.5 and Turbo v2.5 consume
0.5 credit/char. The page states the effective on-demand rates as
**$0.10/1,000 chars (Multilingual)** and **$0.05/1,000 chars (Flash/Turbo)**.
Per-character rate is constant across paid tiers; higher subscription tiers buy
more included credits, not a cheaper per-char rate, though volume/enterprise
commitments negotiate lower.

| Model | $/1M chars | Native basis | Tier | conf | Source (as of 2026-07-11) |
|---|---|---|---|---|---|
| **Flash v2.5** | **$50** | credits: 0.5 credit/char → $0.05/1K chars | low-latency | H | elevenlabs.io/pricing/api |
| **Turbo v2.5** | **$50** | credits: 0.5 credit/char → $0.05/1K chars | balanced | H | elevenlabs.io/pricing/api |
| **Multilingual v2** | **$100** | credits: 1 credit/char → $0.10/1K chars | highest-quality | H | elevenlabs.io/pricing/api |

Streaming vs batch does not change the per-character rate.

## Google Cloud Text-to-Speech

The primary pricing page is JS/section-gated and did not render dollar figures on
fetch; the rates below are Google's long-stable published tiers, corroborated
across multiple 2026 aggregators — treat as **M**. Free tier is per voice type
(Standard 4M chars/mo; WaveNet/Neural2/Chirp 1M chars/mo; Studio 100K chars/mo).
Note the discrepancy caveat: some 2026 aggregators list WaveNet at $4/1M
(conflating it with Standard) — the historically stable and more widely cited
figure is WaveNet **$16/1M**; confirm on the live page before publishing.

| Model / tier | $/1M chars | Native basis | Tier | conf | Source (as of 2026-07-11) |
|---|---|---|---|---|---|
| **Standard** | **$4** | per-1M-characters | non-neural | M | cloud.google.com/text-to-speech/pricing |
| **WaveNet** | **$16** | per-1M-characters | neural | M | cloud.google.com/text-to-speech/pricing |
| **Neural2** | **$16** | per-1M-characters | neural (standard) | M | cloud.google.com/text-to-speech/pricing |
| **Polyglot** | **$16** | per-1M-characters | neural | M | cloud.google.com/text-to-speech/pricing |
| **Chirp 3: HD** | **$30** | per-1M-characters | premium generative | M | cloud.google.com/text-to-speech/pricing |
| **Studio** | **$160** | per-1M-characters | studio/long-form | M | cloud.google.com/text-to-speech/pricing |

Headline for the provider is the standard neural tier (**Neural2 / WaveNet,
$16/1M**); Chirp 3: HD ($30) is the current flagship generative tier.

## Azure AI Speech (Text-to-Speech)

The Azure pricing page renders prices client-side (shows `$-` placeholders on
fetch), so figures are corroborated via 2026 aggregators + Microsoft community
posts — **M**. Billing is per character. Free tier: 500K chars/month. Commitment
tiers cut the effective rate to as low as ~$7.50/1M.

| Model / tier | $/1M chars | Native basis | Tier | conf | Source (as of 2026-07-11) |
|---|---|---|---|---|---|
| **Neural (standard)** | **$16** | per-1M-characters | standard neural | M | azure.microsoft.com/pricing/details/speech |
| **Neural HD** | **$22** | per-1M-characters | HD (reduced from $30 in Mar 2026) | M | azure.microsoft.com/pricing/details/speech |
| **Custom Neural (professional)** | **$24** ($48 HD) | per-1M-characters | custom voice synthesis | M | azure.microsoft.com/pricing/details/speech |

## Amazon Polly

Pricing page fetched directly — **H**. Billing is per character of input text,
by engine. Generated audio can be cached and replayed at no additional cost.
Free tier (first 12 months, by engine): Standard 5M, Neural 1M, Long-form 500K,
Generative 100K chars/month.

| Model / engine | $/1M chars | Native basis | Tier | conf | Source (as of 2026-07-11) |
|---|---|---|---|---|---|
| **Standard** | **$4.00** | per-1M-characters | non-neural | H | aws.amazon.com/polly/pricing |
| **Neural** | **$16.00** | per-1M-characters | standard neural | H | aws.amazon.com/polly/pricing |
| **Generative** | **$30.00** | per-1M-characters | generative | H | aws.amazon.com/polly/pricing |
| **Long-form** | **$100.00** | per-1M-characters | long-form | H | aws.amazon.com/polly/pricing |

## Deepgram (Aura)

Pricing page fetched directly — **H**. Billed per character; the page does not
split streaming vs batch for TTS (uniform per-character rate).

| Model | $/1M chars | Native basis | Tier | conf | Source (as of 2026-07-11) |
|---|---|---|---|---|---|
| **Aura-2** | **$30** ($27 Growth) | per-1K-chars ($0.030/1K PAYG · $0.027/1K Growth) | current flagship | H | deepgram.com/pricing |
| **Aura-1** | **$15** ($13.50 Growth) | per-1K-chars ($0.015/1K PAYG · $0.0135/1K Growth) | first-gen | H | deepgram.com/pricing |

## Cartesia (Sonic)

Plans and included credits fetched directly from the pricing page (**H** for the
plan/credit table). The page does **not** explicitly print the credits-per-
character for Sonic TTS; the widely reported basis is **1 credit/char** for Sonic,
which makes the effective per-1M-char rate the plan's per-credit price — treat the
per-char mapping as **M**. Entry (Pro) works out to ~$50/1M; the Scale plan's
larger credit bundle lowers the effective rate to ~$37/1M.

| Model / tier | $/1M chars | Native basis | Tier | conf | Source (as of 2026-07-11) |
|---|---|---|---|---|---|
| **Sonic — Pro plan** | **~$50** | credits: ~1 credit/char; Pro $5 / 100K credits → $0.00005/char | entry | plan H · char-map M | cartesia.ai/pricing |
| **Sonic — Startup plan** | **~$39** | Startup $49 / 1.25M credits | volume | plan H · char-map M | cartesia.ai/pricing |
| **Sonic — Scale plan** | **~$37** | Scale $299 / 8M credits | volume | plan H · char-map M | cartesia.ai/pricing |

## PlayHT / Play (Play 3.0)

Primary domains (`play.ht`, `play.ai`) were **not reachable** on fetch (DNS
failure through the proxy), so the numbers below come only from 2026 aggregators
— **L**. Reported API pay-as-you-go: **$15/1M chars** (optimized for speed) and
**$30/1M chars** (TTS HD / higher quality). Do not publish as fact until a
primary source is confirmed.

| Model / tier | $/1M chars | Native basis | Tier | conf | Source (as of 2026-07-11) |
|---|---|---|---|---|---|
| **Play 3.0 (speed)** | **$15** (unconfirmed) | per-1M-characters (aggregator) | standard | L | aggregators only; primary unreachable |
| **Play 3.0 (HD)** | **$30** (unconfirmed) | per-1M-characters (aggregator) | HD | L | aggregators only; primary unreachable |

## Rime (Arcana / Mist)

Rates come from Rime's pricing/blog pages via search (not a clean primary fetch)
— **M**. Rime bills per character. Per-model published rates:

| Model | $/1M chars | Native basis | Tier | conf | Source (as of 2026-07-11) |
|---|---|---|---|---|---|
| **Mist (Mistv2)** | **$30** | per-1K-chars ($0.03/1K) | fast/efficient | M | rime.ai/pricing |
| **Arcana** | **$40** | per-1K-chars ($0.04/1K) | expressive flagship | M | rime.ai/pricing |
| **Coda** | **$50** | per-1K-chars ($0.05/1K) | premium | M | rime.ai/pricing |

## Hume (Octave)

Overage/usage rates fetched directly from the Hume pricing page — **H** for the
per-1,000-character figures. Octave bills per character; the marginal
("additional characters") rate is $0.15/1K on entry tiers, dropping with plan
level. Note: some aggregators cite an "Octave 2 $7.60/1M" figure that is **not**
supported by the primary pricing page — do not publish it (see Do not publish).

| Model / tier | $/1M chars | Native basis | Tier | conf | Source (as of 2026-07-11) |
|---|---|---|---|---|---|
| **Octave — Free/Starter/Creator** | **$150** | per-1K-chars ($0.15/1K) | standard | H | hume.ai/pricing |
| **Octave — Pro** | **$120** | per-1K-chars ($0.12/1K) | volume | H | hume.ai/pricing |
| **Octave — Scale** | **$100** | per-1K-chars ($0.10/1K) | volume | H | hume.ai/pricing |
| **Octave — Business** | **$50** | per-1K-chars ($0.05/1K) | volume | H | hume.ai/pricing |

## Headline $/1M-char leaderboard (standard PAYG, most-common neural tier)

Cheapest → dearest, for orientation only (voice quality/tiers differ sharply —
read the rows). Where a provider has multiple tiers, its standard neural tier is
used; premium tiers noted in parentheses.

| $/1M chars | Model (tier) | conf |
|---|---|---|
| $4 | Amazon Polly Standard · Google Standard (non-neural) | H · M |
| $15 | OpenAI tts-1 · Deepgram Aura-1 · Play 3.0 speed (unconfirmed) | H · H · L |
| $16 | Amazon Polly Neural · Azure Neural · Google Neural2/WaveNet | H · M · M |
| $22 | Azure Neural HD | M |
| $30 | OpenAI tts-1-hd · Deepgram Aura-2 · Amazon Polly Generative · Google Chirp 3 HD · Rime Mist · Play 3.0 HD (unconfirmed) | H · H · H · M · M · L |
| $40 | Rime Arcana | M |
| $50 | ElevenLabs Flash/Turbo v2.5 · Cartesia Sonic (Pro) · Rime Coda · Hume Octave (Business) | H · M · M · H |
| $100 | ElevenLabs Multilingual v2 · Amazon Polly Long-form · Hume Octave (Scale) | H · H · H |
| $150 | Hume Octave (Starter/entry) | H |
| $160 | Google Studio | M |

OpenAI `gpt-4o-mini-tts` is token-billed (~$15–17/1M-char *estimate* only) and is
deliberately excluded from the sortable leaderboard — see below.

## Natively per-character vs credit-based vs token-based

- **Natively per-character (bill == input characters; the clean case):** OpenAI
  `tts-1` / `tts-1-hd` (printed per 1M chars), Amazon Polly (all engines), Google
  Cloud TTS (all tiers), Azure AI Speech (all tiers), Deepgram Aura-1/Aura-2
  (per 1K chars), Rime (per 1K chars), Hume Octave (per 1K chars). Convert with
  `$/1K × 1000 = $/1M`; per-1M figures pass through unchanged.
- **Credit-based (credits map to characters at a stated ratio):** ElevenLabs
  (Multilingual v2 = 1 credit/char → $100/1M; Flash/Turbo v2.5 = 0.5 credit/char
  → $50/1M) and Cartesia Sonic (~1 credit/char; effective rate is the plan's
  per-credit price). The per-1M-char figure is the credit price divided through
  the credit→char ratio; for Cartesia the ratio is corroborated, not printed
  (M).
- **Token-based (need a per-char-equivalent computation, and it must be
  flagged):** OpenAI `gpt-4o-mini-tts` — meters text-input tokens ($0.60/1M) +
  audio-output tokens ($12/1M). The page prints **no** per-char or per-minute
  rate; the ~$15–17/1M-char figure is a computed estimate at a stated assumption
  (~$0.015/min audio, ~900 chars/min). Display the token mechanism, not just the
  number.
- **Streaming vs batch:** does not change the per-character price for any TTS
  provider here (unlike speech-to-text). Cost is a function of input text length,
  not output audio duration or delivery mode.

## Do not publish as fact (unconfirmed / caveated)

1. **PlayHT / Play 3.0 ($15/1M speed, $30/1M HD)** — both `play.ht` and
   `play.ai` were unreachable on fetch (DNS failure through the proxy). The
   numbers are from 2026 aggregators only; no primary confirmation. Publish as
   **L** or withhold until a primary source is fetched.
2. **Google Cloud TTS rates** — the primary pricing page is JS/section-gated and
   returned no dollar figures on fetch; all tier prices are corroborated via
   aggregators against Google's long-stable published rates (M). Specifically,
   **WaveNet**: some 2026 aggregators list $4/1M (conflating it with Standard);
   the historically stable and more widely cited figure is **$16/1M** — confirm
   on the live page before publishing the WaveNet row.
3. **Azure AI Speech rates ($16 Neural / $22 Neural HD / $24 Custom)** — primary
   page renders prices client-side ($- on fetch); corroborated via 2026
   aggregators + Microsoft community posts. Publish as **M**. The Neural HD drop
   from $30 to $22 is dated to March 2026 by aggregators, not confirmed on a
   primary snapshot.
4. **Cartesia Sonic credits-per-character** — the pricing page prints the plan
   credit bundles (Pro $5/100K, Startup $49/1.25M, Scale $299/8M — plan H) but
   **not** the credits-per-character for Sonic TTS. The ~1 credit/char basis
   (hence ~$50/1M at Pro, ~$37/1M at Scale) is corroborated by aggregators, not
   the primary page — publish the per-char mapping as **M**. Sonic 3 may consume
   fewer credits/char than Sonic 2; not confirmed.
5. **OpenAI `gpt-4o-mini-tts` per-character equivalent (~$15–17/1M)** — this is a
   computed *estimate*, not the metered bill (which is token-based: $0.60/1M
   text-input + $12/1M audio-output tokens, both H). OpenAI does not print a
   per-char or per-minute rate for this model. Always render with the token
   mechanism and the "estimate" caveat; never present a flat per-char price.
6. **Hume "Octave 2 $7.60/1M"** — cited by some 2026 aggregators but **not**
   supported by the primary Hume pricing page, whose marginal rate is $0.15/1K
   ($150/1M) on entry tiers down to $0.05/1K ($50/1M) on Business. Do not publish
   the $7.60 figure; use the primary per-1K overage rates.
7. **Rime rates ($30 Mist / $40 Arcana / $50 Coda per 1M)** — from Rime's
   pricing/blog pages via search, not a clean primary fetch. Consistent across
   Rime's own pages but publish as **M** until fetched directly.
8. **ElevenLabs volume/enterprise effective rates** — the $50/1M (Flash/Turbo)
   and $100/1M (Multilingual v2) headline is the published on-demand per-char
   rate (H); large-volume and enterprise commitments negotiate below this, but no
   specific discounted per-char figure is published — do not publish a lower
   ElevenLabs number as a standard rate.
</content>
</invoke>
