# Roadmap — July 2026

A pin in the product. Full rationale, findings, and the pressure test behind
every line here live in `docs/PRODUCT_ANGLE_REVIEW.md`.

**What this is:** the price record of AI model APIs — every price dated,
sourced, and watched for changes. Full from-launch history for language
models; history for the other categories begins when tracking begins.

**Goals it serves:** a product to be proud of, some traffic, low
maintenance. Not category-winning.

The split below is fix vs. enhance: the short-term goal is that the product
*hangs together* — copy and journeys all make sense — and everything
additive waits behind that.

## 1. Hang together (now — fixes only)

### Copy says what the product is

- Category-aware hero on the models index (eyebrow / H1 / subhead from
  `ModelCategory`, which already holds per-tab copy); only the tracked tier
  claims "updated daily, full price history".
- Default `<title>`/meta/OG and Organization JSON-LD in the layout: re-scope
  from "LLM API token prices" to the record framing.
- Footer tagline: drop "USD per 1M tokens" as a site-wide claim.
- Page titles on /compare, /events, /changes: category-neutral.
- llms.txt: describe all seven categories and list their URLs; state the
  two tiers (tracked history vs. dated list prices).
- PWA manifest description and README to match.
- Learn index re-lede: the explainers cover per-token pricing, where the
  complexity concentrates — say so instead of implying it's the whole
  product.

### Journeys make sense

- Model page breadcrumb returns to the model's own category tab, not the
  language table.
- Provider pages group models by category and use each category's column
  shape (today: hardcoded Input/Output/Context with blank cells for
  non-token models).
- Compare is scoped to one category (picker B follows picker A); native-
  priced pairs get a sensible row shape (price headline, pricing model,
  released) instead of per-token dashes; the homepage compare tray resets
  on category change.
- Events launch entries render `price_headline` for native-priced models
  instead of an empty per-token I/O line.
- The untracked-price fallback on model pages reads the category's unit
  (today a video model is described as "priced per image").
- Model-page JSON-LD `category` uses the modality label, not a hardcoded
  "LLM API model".
- `priced_as_of` shown on the directory tab tables, not only the show page.
- Category tab switches preserve scroll position (small Stimulus sprinkle;
  the switches are already Turbo visits — see the review appendix).

### The data layer doesn't contradict itself

- The public JSON API was removed (July 2026): a commodity surface (LiteLLM,
  models.dev) that seeded no flywheel worth its upkeep and contradicted
  itself (token-unit envelope over native prices). The `PriceCatalog` seam
  stays internal; see the `PRODUCT_VISION.md` July update.
- Append a dated snapshot when a native price changes instead of
  overwriting (manual re-verification starts depositing history — the claim
  "history begins when tracking begins" becomes true).
- Schedule `PricingStaleness` weekly in `config/recurring.yml` with a Slack
  ping via `SlackNotifier` (the re-verification chore becomes
  un-forgettable; the copy's honesty stops depending on memory).

## 2. Grow (next — the stated focus once coherent)

- **More models.** Language grows semi-automatically (OpenRouter sync +
  candidate queue). Deliberate effort goes to the directory categories via
  the curation queue and seed docs. Re-verification runs as a rotation —
  one category per month (~8–22 rows, an evening; each category refreshed
  roughly twice a year) — instead of the all-at-once October cliff.
- **Education.** In order: the umbrella explainer ("Billing units across AI
  APIs" — the page every category tab can cross-link); regroup the learn
  index into "Per-token pricing" / "Other billing units"; then the
  per-category pieces demand-gated — generation (image/video), then speech
  (STT+TTS), then embeddings if its umbrella section outgrows itself.
  Rerank stays a paragraph in the umbrella. New widget plumbing: a
  min/median/max strip off each category's `price_headline` values.

## 3. Enhance (later — additive, pinned)

- **RSS change feed** off /changes — the shortest path from the record to a
  return-visit habit; preferred over email (no subscriber-support burden).
- **Benchmarks layer** — quality indication next to prices, entering the
  same way prices do: sourced, dated, attributed, never the site's own
  verdict. Researched and feasible (details and licensing table in the
  review doc): start with the Arena leaderboard dataset (CC-BY-4.0, covers
  language/image/video in one ingestion job), MTEB for embeddings, Open ASR
  for STT, Epoch AI for static evals; TTS and rerank honestly show "no
  independent score"; Artificial Analysis only with their permission.
  Ingestion as a scheduled job in the `ModelSync` mould; label Elo,
  static-eval, and usage signals as different kinds of number.

## Standing maintenance budget

Recurring human work stays at: model-candidate review (minutes), market-
event curation (discretionary), one directory category re-verified per
month, a weekly glance at the staleness ping. Out of budget by default:
email products, breadth-chasing, and any new standing content commitment
beyond the education track above.
