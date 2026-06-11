# Seed price verification checklist (Wayback Machine)

Manual verification of every price point in `db/seeds.rb` against archived
copies of the provider pricing pages, as of June 2026. Work through one
snapshot at a time — each snapshot verifies several rows at once.

## How to use this checklist

1. Open the Wayback URL. The `web/YYYYMMDD/` form redirects to the nearest
   capture; confirm the capture date shown in the Wayback toolbar is **on or
   after** the seed's `effective_on` date (and before the next price change),
   otherwise pick a different capture from the calendar view.
2. Compare input / output / cached-input prices per 1M tokens against the
   expected values. All figures are USD, standard API tier (not batch).
3. Tick the box if it matches. On a mismatch, record what the snapshot
   actually shows in the **Findings** section at the bottom.

**Fixing mismatches in `db/seeds.rb`:**

- *Wrong launch price* → correct the existing price point's values.
- *Wrong effective date* → correct `on:` (re-seeding prunes the old-dated
  point automatically).
- *Price changed later and we missed it* → append a new entry to that
  model's `prices` array with the later `effective_on`; keep the old one.

---

## Pass A — verify each recorded price point

### Anthropic — `https://www.anthropic.com/pricing`

> 2023 captures may show per-1K or per-character rates, or link out to a
> pricing PDF (`www-cdn.anthropic.com/.../pricing.pdf`) — normalize to per-MTok.

- [ ] **Snapshot ~2023-08-20** — <https://web.archive.org/web/20230820/https://www.anthropic.com/pricing>
  - [ ] Claude 2: $11.02 in / $32.68 out (effective 2023-07-11)
  - [ ] Claude Instant: $1.63 / $5.51 (effective 2023-03-14 — the rate already appears in Anthropic's April 2023 pricing PDF; an earlier ~2023-05 capture also works)
- [ ] **Snapshot ~2023-12-01** — <https://web.archive.org/web/20231201/https://www.anthropic.com/pricing>
  - [ ] Claude 2.1: $8 / $24 (effective 2023-11-21)
  - [ ] Claude Instant repriced: $0.80 / $2.40 (effective 2023-11-21 — date approximate, seeded as "alongside Claude 2.1"; if the capture disagrees, correct `on:`)
- [ ] **Snapshot ~2024-11-15** — <https://web.archive.org/web/20241115/https://www.anthropic.com/pricing>
  - [ ] Claude 3.5 Haiku launch: $1 / $5 (effective 2024-10-22 — discovered via LiteLLM history; the seed previously recorded the post-cut price as the launch price)
- [ ] **Snapshot ~2024-12-10** — <https://web.archive.org/web/20241210/https://www.anthropic.com/pricing>
  - [ ] Claude 3.5 Haiku after 20% cut: $0.80 / $4 (effective 2024-12-03)
- [ ] **Snapshot ~2025-03-01** — <https://web.archive.org/web/20250301/https://www.anthropic.com/pricing>
  - [ ] Claude 3.7 Sonnet: $3 / $15 / $0.30 cached (effective 2025-02-24)
- [ ] **Snapshot ~2025-06-01** — <https://web.archive.org/web/20250601/https://www.anthropic.com/pricing>
  - [ ] Claude Opus 4: $15 in / $75 out / $1.50 cached (effective 2025-05-22)
  - [ ] Claude Sonnet 4: $3 / $15 / $0.30 (effective 2025-05-22)
- [ ] **Snapshot ~2025-08-15** — <https://web.archive.org/web/20250815/https://www.anthropic.com/pricing>
  - [ ] Claude Opus 4.1: $15 / $75 / $1.50 (effective 2025-08-05)
- [ ] **Snapshot ~2025-10-20** — <https://web.archive.org/web/20251020/https://www.anthropic.com/pricing>
  - [ ] Claude Sonnet 4.5: $3 / $15 / $0.30 (effective 2025-09-29)
  - [ ] Claude Haiku 4.5: $1 / $5 / $0.10 (effective 2025-10-15)
- [ ] **Snapshot ~2025-12-01** — <https://web.archive.org/web/20251201/https://www.anthropic.com/pricing>
  - [ ] Claude Opus 4.5: $5 / $25 / $0.50 (effective 2025-11-24 — the 67% cut from $15/$75)
- [ ] **Snapshot ~2026-02-25** — <https://web.archive.org/web/20260225/https://www.anthropic.com/pricing>
  - [ ] Claude Opus 4.6: $5 / $25 / $0.50 (effective 2026-02-05)
  - [ ] Claude Sonnet 4.6: $3 / $15 / $0.30 (effective 2026-02-17)
- [ ] **Snapshot ~2026-04-20** — <https://web.archive.org/web/20260420/https://www.anthropic.com/pricing>
  - [ ] Claude Opus 4.7: $5 / $25 / $0.50 (effective 2026-04-16)
- [ ] **Snapshot ~2026-06-10** — <https://web.archive.org/web/20260610/https://www.anthropic.com/pricing>
  - [ ] Claude Fable 5: $10 / $50 / $1.00 (effective 2026-06-09 — very recent; a capture may not exist yet)
  - [ ] Claude Opus 4.8: $5 / $25 / $0.50 (effective 2026-05-28)

### OpenAI — `https://openai.com/api/pricing/`

> Pre-Sep-2023 points live on the older `https://openai.com/pricing` page
> (the `/api/pricing/` URL is newer), quoted per-1K tokens — multiply by 1,000.

- [ ] **Snapshot ~2023-04-01** — <https://web.archive.org/web/20230401/https://openai.com/pricing>
  - [ ] GPT-3.5 Turbo launch: $2 / $2 (effective 2023-03-01; page shows $0.002/1K flat)
- [ ] **Snapshot ~2023-07-01** — <https://web.archive.org/web/20230701/https://openai.com/pricing>
  - [ ] GPT-3.5 Turbo after input cut: $1.50 / $2 (effective 2023-06-13; page shows $0.0015/$0.002 per 1K)
- [ ] **Snapshot ~2023-11-20** — <https://web.archive.org/web/20231120/https://openai.com/pricing>
  - [ ] GPT-3.5 Turbo 1106: $1 / $2 (effective 2023-11-06; page shows $0.001/$0.002 per 1K)
- [ ] **Snapshot ~2024-02-10** — <https://web.archive.org/web/20240210/https://openai.com/pricing>
  - [ ] GPT-3.5 Turbo 0125: $0.50 / $1.50 (effective 2024-01-25; page shows $0.0005/$0.0015 per 1K)
- [ ] **Snapshot ~2025-02-10** — <https://web.archive.org/web/20250210/https://openai.com/api/pricing/>
  - [ ] o1-mini repriced: $1.10 / $4.40 (effective 2025-01-31 — assumed to coincide with the o3-mini launch, date approximate; if the capture disagrees, correct `on:`)
- [ ] **Snapshot ~2025-04-20** — <https://web.archive.org/web/20250420/https://openai.com/api/pricing/>
  - [ ] GPT-4.1: $2 / $8 / $0.50 (effective 2025-04-14)
  - [ ] GPT-4.1 Mini: $0.40 / $1.60 / $0.10 (effective 2025-04-14)
  - [ ] GPT-4.1 Nano: $0.10 / $0.40 / $0.025 (effective 2025-04-14)
  - [ ] o3 launch price: $10 / $40 / $2.50 (effective 2025-04-16)
  - [ ] o4-mini: $1.10 / $4.40 / $0.275 (effective 2025-04-16)
- [ ] **Snapshot ~2025-06-15** — <https://web.archive.org/web/20250615/https://openai.com/api/pricing/>
  - [ ] o3 after 80% cut: $2 / $8 / $0.50 (effective 2025-06-10)
  - [ ] o3-pro: $20 / $80, no cached rate seeded (effective 2025-06-10, launched alongside the o3 cut)
- [ ] **Snapshot ~2025-08-10** — <https://web.archive.org/web/20250810/https://openai.com/api/pricing/>
  - [ ] GPT-5: $0.625 / $5 / $0.0625 (effective 2025-08-07)
- [ ] **Snapshot ~2026-04-28** — <https://web.archive.org/web/20260428/https://openai.com/api/pricing/>
  - [ ] GPT-5.5: $5 / $30 / $0.50 (effective 2026-04-23)
  - [ ] GPT-5.5 Pro: $30 / $180, no cached rate seeded (effective 2026-04-24)

### Google — `https://ai.google.dev/gemini-api/docs/pricing`

> Seed prices are the **≤200K-token context tier** — read the correct column.

- [ ] **Snapshot ~2025-06-20** — <https://web.archive.org/web/20250620/https://ai.google.dev/gemini-api/docs/pricing>
  - [ ] Gemini 2.5 Pro: $1.25 / $10 / $0.125 (effective 2025-06-17)
  - [ ] Gemini 2.5 Flash: $0.30 / $2.50 / $0.03 (effective 2025-06-17; flat pricing, no tiers)
- [ ] **Snapshot ~2025-11-20** — <https://web.archive.org/web/20251120/https://ai.google.dev/gemini-api/docs/pricing>
  - [ ] Gemini 3 Pro: $2 / $12 / $0.20 (effective 2025-11-18)
- [ ] **Snapshot ~2025-12-20** — <https://web.archive.org/web/20251220/https://ai.google.dev/gemini-api/docs/pricing>
  - [ ] Gemini 3 Flash: $0.50 / $3 / $0.05 (effective 2025-12-17)
- [ ] **Snapshot ~2026-02-25** — <https://web.archive.org/web/20260225/https://ai.google.dev/gemini-api/docs/pricing>
  - [ ] Gemini 3.1 Pro: $2 / $12 / $0.20 (effective 2026-02-19)
- [ ] **Snapshot ~2026-05-25** — <https://web.archive.org/web/20260525/https://ai.google.dev/gemini-api/docs/pricing>
  - [ ] Gemini 3.5 Flash: $1.50 / $9 / $0.15 (effective 2026-05-19)

### xAI — `https://docs.x.ai` (models/pricing page)

- [ ] **Snapshot ~2024-11-10** — <https://web.archive.org/web/20241110/https://docs.x.ai>
  - [ ] Grok 2 public API beta: $5 / $15 (effective 2024-10-21 — grok-beta pricing, date approximate; discovered via LiteLLM history)
- [ ] **Snapshot ~2024-12-20** — <https://web.archive.org/web/20241220/https://docs.x.ai>
  - [ ] Grok 2 repriced: $2 / $10 (effective 2024-12-12, the grok-2-1212 release — the seed previously dated this price to the Aug 2024 model announcement, before API pricing existed)
- [ ] **Snapshot ~2025-04-20** — <https://web.archive.org/web/20250420/https://docs.x.ai>
  - [ ] Grok 3: $3 / $15 (effective 2025-04-09 — grok-3-beta API availability date; model previewed Feb 2025)
- [ ] **Snapshot ~2025-07-15** — <https://web.archive.org/web/20250715/https://docs.x.ai>
  - [ ] Grok 4: $3 / $15 / $0.75 (effective 2025-07-09)
- [ ] **Snapshot ~2025-11-25** — <https://web.archive.org/web/20251125/https://docs.x.ai>
  - [ ] Grok 4.1 Fast: $0.20 / $0.50 / $0.05 (effective 2025-11-19)
- [ ] **Snapshot ~2026-05-05** — <https://web.archive.org/web/20260505/https://docs.x.ai>
  - [ ] Grok 4.3: $1.25 / $2.50 / $0.20 (effective 2026-04-30)
- [ ] **Snapshot ~2026-05-25** — <https://web.archive.org/web/20260525/https://x.ai/news/grok-build-0-1>
  - [ ] Grok Build 0.1: $1 / $2 / $0.20 (effective 2026-05-20; seeded from the announcement post — cross-check docs.x.ai too)
- [ ] **Snapshot ~2026-03-15** — <https://web.archive.org/web/20260315/https://openrouter.ai/x-ai/grok-4.20>
  - [ ] Grok 4.20: $2 / $6 / $0.20 (effective 2026-03-10; seeded from OpenRouter, not first-party — seed notes it was later realigned to Grok 4.3 pricing, so use a capture near launch)

### DeepSeek — `https://api-docs.deepseek.com` (pricing page)

- [ ] **Snapshot ~2024-05-20** — <https://web.archive.org/web/20240520/https://api-docs.deepseek.com> (try also `platform.deepseek.com` — the docs domain may postdate V2)
  - [ ] DeepSeek V2: $0.14 / $0.28 (effective 2024-05-06; seeded from the widely reported 1/2 RMB per MTok converted to USD — **flagged unverified in the seed**, this capture is the confirmation)
- [ ] **Snapshot ~2025-02-01** — <https://web.archive.org/web/20250201/https://api-docs.deepseek.com>
  - [ ] DeepSeek R1: $0.55 / $2.19 / $0.14 (effective 2025-01-20)
- [ ] **Snapshot ~2025-02-15** — <https://web.archive.org/web/20250215/https://api-docs.deepseek.com>
  - [ ] DeepSeek V3 post-promotional: $0.27 / $1.10 / $0.027 (effective 2025-02-09)
- [ ] **Snapshot ~2025-10-05** — <https://web.archive.org/web/20251005/https://api-docs.deepseek.com>
  - [ ] DeepSeek V3 after V3.2-Exp cut: $0.28 / $0.42 / $0.028 (effective 2025-09-29)
  - [ ] DeepSeek R1 (deepseek-reasoner) after the same cut: $0.28 / $0.42 / $0.028 (effective 2025-09-29 — discovered via LiteLLM history)
- [ ] **Snapshot ~2026-04-28** — <https://web.archive.org/web/20260428/https://api-docs.deepseek.com>
  - [ ] DeepSeek V4 Pro launch: $1.74 / $3.48 / $0.0145 (effective 2026-04-24)
  - [ ] DeepSeek V4 Flash: $0.14 / $0.28 / $0.0028 (effective 2026-04-24)
- [ ] **Snapshot ~2026-05-25** — <https://web.archive.org/web/20260525/https://api-docs.deepseek.com>
  - [ ] DeepSeek V4 Pro after permanent 75% discount: $0.435 / $0.87 / $0.003625 (effective 2026-05-22; seeded from an Engadget article — this confirms it on the first-party page)

### Mistral — `https://mistral.ai/pricing`

> Early captures live at `docs.mistral.ai/platform/pricing` and quote EUR —
> the seed records the USD list rates that appeared in early 2024.

- [ ] **Snapshot ~2024-03-10** — <https://web.archive.org/web/20240310/https://docs.mistral.ai/platform/pricing/>
  - [ ] Mixtral 8x7B: $0.70 / $0.70 (effective 2024-02-26 — the Au Large release renamed `mistral-small` to `open-mixtral-8x7b` and introduced USD list pricing; the Dec 2023 endpoint was EUR-priced ~€0.60/€1.80)
  - [ ] Mistral 7B: $0.25 / $0.25 (effective 2024-02-26 — `mistral-tiny` became `open-mistral-7b` in the same release; previously ~€0.14/€0.42)
- [ ] **Snapshot ~2024-08-01** — <https://web.archive.org/web/20240801/https://mistral.ai/technology/#pricing>
  - [ ] Mistral Large 2 launch: $3 / $9 (effective 2024-07-24)
- [ ] **Snapshot ~2024-09-25** — <https://web.archive.org/web/20240925/https://mistral.ai/technology/#pricing>
  - [ ] Mistral Large 2 after cut: $2 / $6 (effective 2024-09-17 — the "AI in abundance" release; cross-check <https://web.archive.org/web/20240925/https://mistral.ai/news/september-24-release/>)
- [ ] **Snapshot ~2025-12-05** — <https://web.archive.org/web/20251205/https://mistral.ai/pricing>
  - [ ] Mistral Large 3: $0.50 / $1.50 (effective 2025-12-02)
- [ ] **Snapshot ~2026-03-20** — <https://web.archive.org/web/20260320/https://mistral.ai/pricing>
  - [ ] Mistral Small 4: $0.15 / $0.60 (effective 2026-03-16)
- [ ] **Snapshot ~2026-05-05** — <https://web.archive.org/web/20260505/https://mistral.ai/pricing>
  - [ ] Mistral Medium 3.5: $1.50 / $7.50 (effective 2026-04-29)

### Cohere — `https://cohere.com/pricing`

> Seeded as "Command R Plus" (slug `command-r-plus`) because the `+` in the
> marketing name "Command R+" parameterizes away and would collide with
> Command R's slug.

- [ ] **Snapshot ~2024-04-15** — <https://web.archive.org/web/20240415/https://cohere.com/pricing>
  - [ ] Command R+ launch: $3 / $15 (effective 2024-04-04)
  - [ ] Command R launch: $0.50 / $1.50 (effective 2024-03-11)
- [ ] **Snapshot ~2024-09-10** — <https://web.archive.org/web/20240910/https://cohere.com/pricing>
  - [ ] Command R+ (08-2024 refresh): $2.50 / $10 (effective 2024-08-30; cross-check <https://web.archive.org/web/20240910/https://docs.cohere.com/changelog/command-gets-refreshed>)
  - [ ] Command R (08-2024 refresh): $0.15 / $0.60 (effective 2024-08-30)

### Alibaba — `https://www.alibabacloud.com/help/en/model-studio/model-pricing`

- [ ] **Snapshot ~2025-10-01** — <https://web.archive.org/web/20251001/https://www.alibabacloud.com/help/en/model-studio/model-pricing>
  - [ ] Qwen3 Max launch (DashScope): $0.86 / $3.44 (effective 2025-09-23)
- [ ] **Snapshot ~2025-11-20** — <https://web.archive.org/web/20251120/https://www.alibabacloud.com/help/en/model-studio/model-pricing>
  - [ ] Qwen3 Max after 50% cut: $0.46 / $1.84 (effective 2025-11-14; seeded from SCMP coverage — this confirms it first-party)
- [ ] **Snapshot ~2026-05-25** — <https://web.archive.org/web/20260525/https://www.alibabacloud.com/help/en/model-studio/model-pricing>
  - [ ] Qwen 3.7 Max: $2.50 / $7.50 list (effective 2026-05-20; seeded from a blog post, date flagged approximate, and a 50% promo may be displayed — record both list and promo prices if shown)

### Moonshot — `https://platform.moonshot.ai` (pricing page)

- [ ] **Snapshot ~2025-07-20** — <https://web.archive.org/web/20250720/https://platform.moonshot.ai>
  - [ ] Kimi K2: $0.55 / $2.20 / $0.15 (effective 2025-07-11; seeded from pricepertoken.com — first-party confirmation wanted)
- [ ] **Snapshot ~2026-02-01** — <https://web.archive.org/web/20260201/https://platform.moonshot.ai>
  - [ ] Kimi K2.5: $0.60 / $2.50 / $0.10 (effective 2026-01-27)
- [ ] **Snapshot ~2026-04-25** — <https://web.archive.org/web/20260425/https://platform.moonshot.ai>
  - [ ] Kimi K2.6: $0.60 / $2.50 / $0.15 (effective 2026-04-20)

### Meta (open-weight, aggregator-sourced) — `https://pricepertoken.com`

- [ ] **Snapshot ~2024-12-15** — <https://web.archive.org/web/20241215/https://pricepertoken.com>
  - [ ] Llama 3.3 70B: $0.59 / $0.79 (effective 2024-12-06; representative hosted rate (Groq) — Together was $0.88 flat, DeepInfra ~$0.35 flat, so ±20% applies)
- [ ] **Snapshot ~2025-04-15** — <https://web.archive.org/web/20250415/https://pricepertoken.com>
  - [ ] Llama 4 Maverick: $0.15 / $0.60 (effective 2025-04-05; "representative hosted rate")
  - [ ] Llama 4 Scout: $0.08 / $0.30 (effective 2025-04-05; DeepInfra rate)

> Hosted open-weight rates vary by provider; treat ±20% as a pass here, but
> note the exact figure found.

---

## Pass B — staleness check (prices we *assume* still hold)

The seed only records price changes, so for these models the site asserts
"unchanged since the last point" with no verification. Pull **one recent
capture (late May / early June 2026)** of each page and confirm the old
price still appears. Any difference means a missing price point to add.

- [ ] **Anthropic** ~2026-06-01 — <https://web.archive.org/web/20260601/https://www.anthropic.com/pricing>
  - [ ] Sonnet 4.6 still $3 / $15; Haiku 4.5 still $1 / $5; Opus line still $5 / $25
- [ ] **OpenAI** ~2026-06-01 — <https://web.archive.org/web/20260601/https://openai.com/api/pricing/>
  - [ ] GPT-4.1 still $2 / $8 · Mini $0.40 / $1.60 · Nano $0.10 / $0.40 (unchanged ~14 months — highest-suspicion rows in the whole file)
  - [ ] o3 still $2 / $8; o4-mini still $1.10 / $4.40
  - [ ] GPT-5 still $0.625 / $5 (did it survive the GPT-5.5 launch at this price, and is it still listed?)
- [ ] **Google** ~2026-06-01 — <https://web.archive.org/web/20260601/https://ai.google.dev/gemini-api/docs/pricing>
  - [ ] Gemini 2.5 Pro still $1.25 / $10; 2.5 Flash still $0.30 / $2.50 (unchanged ~12 months)
  - [ ] Gemini 3 Pro still $2 / $12; 3 Flash still $0.50 / $3
- [ ] **DeepSeek** ~2026-06-01 — <https://web.archive.org/web/20260601/https://api-docs.deepseek.com>
  - [ ] R1 still $0.55 / $2.19 (now routes to V4 Flash thinking — is it still priced separately?)
  - [ ] V3 still $0.28 / $0.42
- [ ] **Mistral** ~2026-06-01 — <https://web.archive.org/web/20260601/https://mistral.ai/pricing>
  - [ ] Large 3 still $0.50 / $1.50; Small 4 still $0.15 / $0.60
- [ ] **Moonshot** ~2026-06-01 — <https://web.archive.org/web/20260601/https://platform.moonshot.ai>
  - [ ] K2.5 still $0.60 / $2.50 alongside K2.6
- [ ] **Alibaba** ~2026-06-01 — <https://web.archive.org/web/20260601/https://www.alibabacloud.com/help/en/model-studio/model-pricing>
  - [ ] Qwen3 Max still $0.46 / $1.84
- [ ] **Meta / aggregator** ~2026-06-01 — <https://web.archive.org/web/20260601/https://pricepertoken.com>
  - [ ] Llama 4 Maverick still ~$0.15 / $0.60; Scout still ~$0.08 / $0.30
- [ ] **xAI** ~2026-05-10 (before the May 15 retirements) — <https://web.archive.org/web/20260510/https://docs.x.ai>
  - [ ] Grok 4 still $3 / $15 and Grok 4.1 Fast still $0.20 / $0.50 just before retirement
  - [ ] Grok 4.20: seed notes it was "later aligned to Grok 4.3 pricing" ($1.25 / $2.50) but we have **no price point recorded for that change** — if this capture shows the aligned price, add a dated point

### Retired models — verify before their delisting dates

These won't be on June 2026 captures at all:

- [ ] Claude Opus 4 / 4.1 and Sonnet 4 — covered by the 2025 Anthropic snapshots in Pass A
- [ ] Kimi K2 (EOL 2026-05-25) — covered by the 2025-07-20 Moonshot snapshot; optionally re-check ~2026-04-01
- [ ] Grok 4 / Grok 4.1 Fast (retired 2026-05-15) — covered by the xAI ~2026-05-10 capture above

---

## Findings

Record mismatches here as you go, then fold them back into `db/seeds.rb`.

| Model | Seed says | Snapshot shows | Capture date | Action |
|---|---|---|---|---|
| Mistral Large 2 | (was) $2/$6 at launch 2024-07-24 | Web sources (artificialanalysis.ai, docsbot.ai, mistral.ai/news/september-24-release) confirm $3/$9 at the 2024-07-24 launch, cut to $2/$6 in the 2024-09-17 "AI in abundance" release | n/a (Wayback blocked from this environment; confirmed via WebSearch, June 2026) | **Fixed** — seed now has two points: 2024-07-24 $3/$9 and 2024-09-17 $2/$6. Wayback double-check still welcome (Pass A Mistral snapshots above). |
| DeepSeek V2 | $0.14/$0.28 (2024-05-06) | ¥1/¥2 per MTok schedule corroborated by multiple secondary sources (helicone, pricepertoken, BytePlus); primary May 2024 capture still wanted | — | Note upgraded from "unverified" to "corroborated"; see Pass A DeepSeek ~2024-05-20 snapshot. |
| Mixtral 8x7B / Mistral 7B | (was) USD rates dated 2023-12-11 | USD list pricing began with the 2024-02-26 "Au Large" release (mistral.ai/news/mistral-large), which renamed the endpoints to `open-*`; Dec 2023 was EUR-priced | n/a (confirmed via WebSearch, June 2026) | **Fixed** — both points re-dated to 2024-02-26. |
| Claude Instant launch | (was) $1.63/$5.51 dated 2023-08-09 | Rate already appears in Anthropic's April 2023 pricing PDF (www-cdn.anthropic.com apr-2023 capture) | n/a (confirmed via WebSearch, June 2026) | **Fixed** — re-dated to the 2023-03-14 Claude API launch. |
| Claude Instant reprice | $0.80/$2.40 effective 2023-11-21 | Repricing confirmed (Anthropic `model_pricing_nov2023.pdf`; first noticed on HN 2023-12-13) but the exact effective date is assumed to coincide with Claude 2.1 | — | Seeded with "date approximate" note; confirm via the ~2023-12-01 Anthropic snapshot. |
| Claude 3.5 Haiku | (was) $0.80/$4 as launch price | Launched at $1/$5 on 2024-10-22, cut 20% to $0.80/$4 on 2024-12-03 (anthropic.com/news/3-5-models-and-computer-use; LiteLLM history; simonwillison.net) | n/a (confirmed via WebSearch, June 2026) | **Fixed** — split into launch + cut points. |
| o1-mini | (was) single $3/$12 point | Cut to $1.10/$4.40 around the 2025-01-31 o3-mini launch (current OpenAI docs; LiteLLM history) | — | **Fixed** — second point added with "date approximate" flag; confirm via the ~2025-02-10 OpenAI snapshot. |
| Grok 2 | (was) $2/$10 dated 2024-08-13 | API pricing began with the Oct 2024 public beta at $5/$15 (grok-beta); $2/$10 effective 2024-12-12 with grok-2-1212 (xAI announcement; LiteLLM history) | n/a (confirmed via WebSearch, June 2026) | **Fixed** — split into beta + reprice points; beta date flagged approximate. |
| DeepSeek R1 | (was) launch point only | The 2025-09-29 V3.2-Exp repricing also applied to deepseek-reasoner: $0.28/$0.42 (api-docs.deepseek.com; VentureBeat) | n/a (confirmed via WebSearch, June 2026) | **Fixed** — reprice point added. |
