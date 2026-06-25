# Model Guide — copy deck (voice + final strings)

*Companion to `MODEL_GUIDE_PLAN.md`. A surface-by-surface copy pass (homepage, guide, trends/detail,
learn) produced the strings below. The aim throughout: a developer who built the tool, writing for
peers — inform, don't persuade. The original homepage hero ("Every LLM API price, normalized." + a
spec-list subtitle) was the worst offender: abstract, generic, and selling only the table while
ignoring the guide.*

## House style (locked across every screen)

- **"the guide"** lowercase in prose; "Guide" only as the nav tab. No "the model guide"
  (personification).
- **"per call"** is the only cost unit shown to users — never per month. The table keeps
  "per 1M tokens" (the spec unit, a different thing).
- **"No fabricated bills, no rankings."** — verbatim couplet, identical on the footer and the guide.
- **"cost-driver step" / "capable-model step"** — the canonical paired terms, in prose and in the
  step annotations. Retire "expensive step", "smart step", "strong model".
- **"a feature is a chain of calls"** — fixed phrasing for the core idea ("pipeline" allowed as a
  supporting noun).
- **Name the step, not a euphemism** — "save the capable model for Generate," not "where it counts."
- **Headings state the subject, not a verdict** — "Price per 1M tokens, 2023 to 2026," not "Three
  years of falling prices."
- **Captions never restate the big number above them** — attribution (which model, when), not the
  stat.
- **Describe behavior, not pixels** — "click a model to toggle," not "indigo flags."
- No drama em-dashes; no "=" in prose ("means"); "×" only for literal arithmetic. Cross-link
  headings are labels, not questions. Tier ladder is small / mid / frontier (no "nano").
  "near-frontier" not "frontier-ish". "in+out" not "I/O". "open weight" not bare "open".

## Homepage hero (chosen: the decision-bridge)

Leads with the developer's question; the index is the backing. The homepage is the price index, so
this hero fronts the decision while the secondary CTA and subtitle keep the table and history present.

- Eyebrow: `The price index`
- H1: **Which model for what you're building, and what it costs.**
- Subtitle: **Starting points for chatbots, RAG, and coding agents, priced per call against 40+
  models, with full price history since 2023.**
- Primary CTA: `Find a model` · Secondary CTA: `Browse all prices`

(The two runner-up directions, kept for reference: ① history-moat — "Every model's price, and every
price it used to have."; ③ the spread — "The same task runs on a frontier model or one 20× cheaper.")

## Winning copy by screen

**Guide**
- H1: **Your job is a pipeline. Here's a starting model per step, priced per call.**
- Lede: **Most steps run on a small model; one step needs a capable one, and it usually isn't the
  step that drives the bill. Each step gets a starting option and a per-call cost. No fabricated
  bills, no rankings.**
- Footer cross-link heading: `Want the model behind this?` → **Go deeper**.
- All six task ledes rewritten to distinct openings (no repeated "is not one call"); the takeaway
  template rewritten to plain declaratives with the computed step slots intact.

**Homepage / chrome**
- Stat labels: "models tracked" → **models**; "cheapest I/O avg /1M" → **cheapest, in+out avg /1M**.
- Latest-update panel heading: **Latest changes**.
- Footer disclaimer (matches the guide verbatim): **sourced from provider price pages · costs are
  per-call estimates, never a monthly bill**.
- **Credibility fix:** the model count must be **dynamic**, never a rounded-up static "40+". A tool
  whose pitch is "we don't fabricate numbers" can't ship an inflated count; render the live count.

**Trends**
- Heading: "Three years of falling prices." → **Price per 1M tokens, 2023 to 2026.**
- Lede: **Every rate change since launch, by model, with the market events that moved them. History
  no other reference keeps.**
- Stat-card captions carry attribution (which model, when), not the number already shown.

**Model detail**
- "Representative call cost" → **Cost per call**; caption → **Cost of one call at these token
  counts. No fabricated monthly bill.**
- CTA "Use in a pipeline" → **Price this in the guide**.

**Learn / anatomy explainer**
- Index intro (was the most marketing line in the artifact) → **Four explainers on what an LLM
  feature costs and why: the call chain a feature runs, how an API bill reads, where the tokens go,
  and which levers cut it.**
- Anatomy closing callout: "The expensive step and the smart step are usually different." → **The
  cost-driver step and the capable-model step are usually different.** (the headline uses the terms
  the page taught).

## Note

The defining sentence (Plan §1) contains an em-dash. It is fine as an internal anchor; anywhere it
appears as shipped UI, split it into two sentences to match the no-drama rule.
