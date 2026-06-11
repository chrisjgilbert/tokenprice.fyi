# Seed Data Verification Checklist

Items flagged during the June 2026 enrichment that should be verified against
primary pricing pages before treating as authoritative.

## Verified & Fixed (June 11 2026)

| Model | Issue | Resolution |
|-------|-------|------------|
| GPT-5 | Was $0.625/$5; multiple sources say $1.25/$10 | Fixed to $1.25/$10 |
| Gemini 1.5 Pro | Launch price was $3.50/$10.50; should be $7/$21 | Fixed to $7/$21 |
| Gemini 1.5 Pro (2nd snapshot) | Date was Aug 12; major Pro cut was Oct 1 | Fixed to 2024-10-01 |
| Gemini 1.5 Flash | Launch date was May 24; Google I/O was May 14 | Fixed to 2024-05-14 |
| Grok 3 Mini | Date was Feb 17 (Grok 3 base launch); API was Jun 10 | Fixed to 2025-06-10 |
| "GPT-5 sparks price war" event | Referenced old $0.625/$5 figure | Fixed to $1.25/$10 |
| "Gemini 1.5 Pro cut 64%" event | Date was Sep 24; likely Oct 1 | Fixed to 2024-10-01 |

## Still Needs Manual Verification

These were flagged but not changed because primary sources are needed:

### o4-mini pricing tier ambiguity
- **Current**: $1.10/$4.40 (seeds) matches the spreadsheet and several aggregators
- **Concern**: Some sources list $1.10/$4.40 as the "high reasoning effort" tier,
  with a standard tier at $0.55/$2.20
- **Action**: Check openai.com/api/pricing directly to confirm which tier we should track

### Claude 3 Haiku release date
- **Current**: 2024-03-04 (announcement date)
- **Concern**: GA availability was 2024-03-13
- **Action**: Decide whether the site tracks announcement or GA dates and be consistent

### Claude 3.5 Haiku release date
- **Current**: 2024-10-22 (announcement date)
- **Concern**: GA availability was 2024-11-04
- **Action**: Same announcement-vs-GA decision as above

### Gemini 1.5 Pro repricing history
- **Current**: Two snapshots — launch ($7/$21) and Oct 2024 ($1.25/$5)
- **Concern**: There may have been an intermediate price cut (~May 2024 to $3.50/$10.50)
  that we're missing. Adding a third snapshot would give a more complete picture.
- **Action**: Check Google's pricing changelog or Wayback Machine for mid-2024 rates

### Missing model: Grok 3
- The seeds have Grok 2 and Grok 3 Mini but no Grok 3 (full model, ~Feb 2025)
- **Action**: Add Grok 3 with API pricing if available

### Missing provider: Cohere
- The source spreadsheet includes Cohere Command R+ ($2.50/$10) and Command R ($0.15/$0.60)
- **Action**: Consider adding Cohere as a provider with release dates and tier info
