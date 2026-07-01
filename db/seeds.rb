# Seed data for tokenprice.fyi
#
# Idempotent: safe to run repeatedly (`bin/rails db:seed`). Models are keyed by
# slug, price points by [model, effective_on], so re-running updates in place.
#
# Prices are USD per 1,000,000 tokens (standard API tier, not batch/cached unless
# noted). Anthropic figures are authoritative; other providers are best-effort
# from public pricing pages as of June 2026 — verify before relying on them.
#
# This is the file a human edits and a future scraping job appends to: to record
# a price change, add a new price point with a later effective_on. The launch
# point stays, so the history charts draw the change.

# ---------------------------------------------------------------------------
# Providers
# ---------------------------------------------------------------------------
providers = {
  anthropic: { name: "Anthropic", website: "https://www.anthropic.com", accent: "#D97757", country: "United States", country_code: "US" },
  openai:    { name: "OpenAI",    website: "https://openai.com",        accent: "#10A37F", country: "United States", country_code: "US" },
  google:    { name: "Google",    website: "https://ai.google.dev",     accent: "#4285F4", country: "United States", country_code: "US" },
  xai:       { name: "xAI",        website: "https://x.ai",              accent: "#1F2937", country: "United States", country_code: "US" },
  deepseek:  { name: "DeepSeek",  website: "https://www.deepseek.com",  accent: "#4D6BFE", country: "China", country_code: "CN" },
  meta:      { name: "Meta",      website: "https://www.llama.com",     accent: "#0866FF", country: "United States", country_code: "US" },
  mistral:   { name: "Mistral",   website: "https://mistral.ai",        accent: "#FA520F", country: "France", country_code: "FR" },
  cohere:    { name: "Cohere",    website: "https://cohere.com",        accent: "#39594D", country: "Canada", country_code: "CA" },
  alibaba:   { name: "Alibaba",   website: "https://qwen.ai",           accent: "#615CED", country: "China", country_code: "CN" },
  moonshot:  { name: "Moonshot AI", website: "https://www.moonshot.ai", accent: "#2D2A6E", country: "China", country_code: "CN" },
  black_forest_labs: { name: "Black Forest Labs", website: "https://blackforestlabs.ai", accent: "#111827", country: "Germany", country_code: "DE" },
  stability: { name: "Stability AI", website: "https://stability.ai", accent: "#7C3AED", country: "United Kingdom", country_code: "GB" }
}.transform_values do |attrs|
  Provider.find_or_create_by!(slug: attrs[:name].parameterize) do |p|
    p.assign_attributes(attrs)
  end.tap { |p| p.update!(attrs.slice(:website, :accent, :country, :country_code)) }
end

# ---------------------------------------------------------------------------
# Models + dated price history
#
# Each model: tier (frontier|mid|small), status (active|legacy|suspended|retired), context
# window, max output, release date, and a `prices` array of dated snapshots.
# ---------------------------------------------------------------------------
catalog = [
  # ---- Anthropic --------------------------------------------------------
  {
    provider: :anthropic, name: "Claude Fable 5", tier: "frontier", status: "suspended",
    context_window: 1_000_000, max_output_tokens: 128_000, released_on: "2026-06-09",
    description: "Anthropic's most powerful model — a new Mythos-class tier above Opus, aimed at the hardest reasoning and agentic work. Access is currently suspended.",
    prices: [ { on: "2026-06-09", in: 10, out: 50, cached: 1.0, src: "anthropic.com/pricing", note: "List price" } ]
  },
  {
    provider: :anthropic, name: "Claude Opus 4.8", tier: "frontier", status: "active",
    context_window: 1_000_000, max_output_tokens: 128_000, released_on: "2026-05-28",
    description: "Most capable Opus-tier model: highly autonomous, strong on long-horizon agentic work and knowledge tasks. 1M context at standard pricing.",
    prices: [ { on: "2026-05-28", in: 5, out: 25, cached: 0.50, src: "anthropic.com/pricing" } ]
  },
  {
    provider: :anthropic, name: "Claude Opus 4.7", tier: "frontier", status: "legacy",
    context_window: 1_000_000, max_output_tokens: 128_000, released_on: "2026-04-16",
    description: "Previous-generation Opus. Highly autonomous; strong on agentic, vision and memory tasks.",
    prices: [ { on: "2026-04-16", in: 5, out: 25, cached: 0.50, src: "anthropic.com/pricing" } ]
  },
  {
    provider: :anthropic, name: "Claude Opus 4.6", tier: "frontier", status: "legacy",
    context_window: 1_000_000, max_output_tokens: 128_000, released_on: "2026-02-05",
    description: "First Opus with a 1M context window at standard pricing. Same $5/$25 as Opus 4.5.",
    prices: [ { on: "2026-02-05", in: 5, out: 25, cached: 0.50, src: "anthropic.com/pricing" } ]
  },
  {
    provider: :anthropic, name: "Claude Opus 4.5", tier: "frontier", status: "legacy",
    context_window: 200_000, max_output_tokens: nil, released_on: "2025-11-24",
    description: "Introduced the 67% Opus price cut — from $15/$75 (Opus 4/4.1) to $5/$25 — which held through all subsequent Opus releases.",
    prices: [ { on: "2025-11-24", in: 5, out: 25, cached: 0.50, src: "anthropic.com/pricing", note: "67% price cut from Opus 4/4.1" } ]
  },
  {
    provider: :anthropic, name: "Claude Opus 4.1", tier: "frontier", status: "retired",
    context_window: 200_000, max_output_tokens: nil, released_on: "2025-08-05",
    description: "Drop-in replacement for Opus 4 at the same $15/$75 pricing. Superseded by Opus 4.5 at 67% lower price.",
    prices: [ { on: "2025-08-05", in: 15, out: 75, cached: 1.50, src: "anthropic.com/pricing" } ]
  },
  {
    provider: :anthropic, name: "Claude Opus 4", tier: "frontier", status: "retired",
    context_window: 200_000, max_output_tokens: nil, released_on: "2025-05-22",
    description: "Original Claude 4 flagship at $15/$75. Superseded by Opus 4.5 which cut pricing by 67%.",
    prices: [ { on: "2025-05-22", in: 15, out: 75, cached: 1.50, src: "anthropic.com/pricing" } ]
  },
  {
    provider: :anthropic, name: "Claude Sonnet 4.6", tier: "mid", status: "active",
    context_window: 1_000_000, max_output_tokens: 64_000, released_on: "2026-02-17",
    description: "Anthropic's best balance of speed and intelligence. 1M context window. Sonnet pricing has held flat at $3/$15 across all 4.x releases.",
    prices: [ { on: "2026-02-17", in: 3, out: 15, cached: 0.30, src: "anthropic.com/pricing" } ]
  },
  {
    provider: :anthropic, name: "Claude Sonnet 4.5", tier: "mid", status: "legacy",
    context_window: 1_000_000, max_output_tokens: 64_000, released_on: "2025-09-29",
    description: "Previous Sonnet generation. Same $3 / $15 pricing as 4.6 — Sonnet pricing has held flat.",
    prices: [ { on: "2025-09-29", in: 3, out: 15, cached: 0.30, src: "anthropic.com/pricing" } ]
  },
  {
    provider: :anthropic, name: "Claude Sonnet 4", tier: "mid", status: "retired",
    context_window: 200_000, max_output_tokens: nil, released_on: "2025-05-22",
    description: "Original Claude 4 Sonnet. Same $3/$15 pricing carried through all subsequent Sonnet 4.x releases.",
    prices: [ { on: "2025-05-22", in: 3, out: 15, cached: 0.30, src: "anthropic.com/pricing" } ]
  },
  {
    provider: :anthropic, name: "Claude Haiku 4.5", tier: "small", status: "active",
    context_window: 200_000, max_output_tokens: 64_000, released_on: "2025-10-15",
    description: "Fastest and most cost-effective Claude model. Pricing held flat since launch — no newer Haiku has been released.",
    prices: [ { on: "2025-10-15", in: 1, out: 5, cached: 0.10, src: "anthropic.com/pricing" } ]
  },
  {
    provider: :anthropic, name: "Claude 3.7 Sonnet", tier: "mid", status: "retired",
    context_window: 200_000, max_output_tokens: nil, released_on: "2025-02-24",
    description: "First hybrid reasoning Claude — extended thinking at the same $3/$15 Sonnet price point, with thinking tokens billed as output. Superseded by Sonnet 4.",
    prices: [ { on: "2025-02-24", in: 3, out: 15, cached: 0.30, src: "anthropic.com/pricing" } ]
  },
  {
    provider: :anthropic, name: "Claude 3.5 Sonnet", tier: "mid", status: "retired",
    context_window: 200_000, max_output_tokens: nil, released_on: "2024-06-20",
    description: "Major quality leap — beat Claude 3 Opus at one-fifth the price. Updated Oct 2024 with computer use support.",
    prices: [ { on: "2024-06-20", in: 3, out: 15, src: "anthropic.com/pricing" } ]
  },
  {
    provider: :anthropic, name: "Claude 3.5 Haiku", tier: "small", status: "retired",
    context_window: 200_000, max_output_tokens: nil, released_on: "2024-10-22",
    description: "Upgraded Haiku — significantly more capable than Claude 3 Haiku but priced higher. Launched at $1/$5, cut 20% to $0.80/$4 six weeks later.",
    prices: [
      { on: "2024-10-22", in: 1, out: 5, src: "anthropic.com/pricing", note: "Launch pricing" },
      { on: "2024-12-03", in: 0.80, out: 4, src: "anthropic.com/pricing", note: "20% price cut" }
    ]
  },
  {
    provider: :anthropic, name: "Claude 3 Opus", tier: "frontier", status: "retired",
    context_window: 200_000, max_output_tokens: nil, released_on: "2024-03-04",
    description: "Original Claude 3 flagship. $15/$75 price point held through Opus 4/4.1 until the 67% cut with Opus 4.5.",
    prices: [ { on: "2024-03-04", in: 15, out: 75, src: "anthropic.com/pricing" } ]
  },
  {
    provider: :anthropic, name: "Claude 3 Sonnet", tier: "mid", status: "retired",
    context_window: 200_000, max_output_tokens: nil, released_on: "2024-03-04",
    description: "Claude 3 mid-tier — established the $3/$15 price point that Sonnet has maintained across every subsequent generation.",
    prices: [ { on: "2024-03-04", in: 3, out: 15, src: "anthropic.com/pricing" } ]
  },
  {
    provider: :anthropic, name: "Claude 3 Haiku", tier: "small", status: "retired",
    context_window: 200_000, max_output_tokens: nil, released_on: "2024-03-04",
    description: "Ultra-cheap Claude at $0.25/$1.25 — staked out the fast-and-cheap tier against GPT-3.5 Turbo.",
    prices: [ { on: "2024-03-04", in: 0.25, out: 1.25, src: "anthropic.com/pricing" } ]
  },
  {
    provider: :anthropic, name: "Claude 2.1", tier: "frontier", status: "retired",
    context_window: 200_000, max_output_tokens: nil, released_on: "2023-11-21",
    description: "Doubled context to 200K and cut flagship pricing from Claude 2's $11.02/$32.68 to $8/$24 — the price point Mistral Large would later match.",
    prices: [ { on: "2023-11-21", in: 8, out: 24, src: "anthropic.com/pricing" } ]
  },
  {
    provider: :anthropic, name: "Claude Instant", tier: "small", status: "retired",
    context_window: 100_000, max_output_tokens: nil, released_on: "2023-03-14",
    description: "Anthropic's original fast-and-cheap tier, predating Haiku. Repriced from $1.63/$5.51 to $0.80/$2.40 in late 2023.",
    prices: [
      { on: "2023-03-14", in: 1.63, out: 5.51, src: "anthropic.com/pricing", note: "Rate appears in Anthropic's April 2023 pricing PDF; dated to the Claude API launch" },
      { on: "2023-11-21", in: 0.80, out: 2.40, src: "anthropic.com/pricing", note: "Repriced alongside Claude 2.1; value confirmed via Wayback (old $1.63/$5.51 at 2023-11-17, new $0.80/$2.40 by 2024-01-16); exact date falls in that capture gap, consistent with the 2023-11-21 Claude 2.1 release" }
    ]
  },
  {
    provider: :anthropic, name: "Claude 2", tier: "frontier", status: "retired",
    context_window: 100_000, max_output_tokens: nil, released_on: "2023-07-11",
    description: "Anthropic's pre-Claude-3 flagship at $11.02/$32.68 — odd figures from converting the original per-character rates to per-token. Pricing fell to $8/$24 with Claude 2.1.",
    prices: [ { on: "2023-07-11", in: 11.02, out: 32.68, src: "anthropic.com/pricing", note: "Launch list price" } ]
  },

  # ---- OpenAI -----------------------------------------------------------
  {
    provider: :openai, name: "GPT-5.5 Pro", tier: "frontier", status: "active",
    context_window: 1_000_000, max_output_tokens: 128_000, released_on: "2026-04-24",
    description: "Highest-accuracy reasoning variant of GPT-5.5.",
    prices: [ { on: "2026-04-24", in: 30, out: 180, src: "openai.com/api/pricing" } ]
  },
  {
    provider: :openai, name: "GPT-5.5", tier: "frontier", status: "active",
    context_window: 1_000_000, max_output_tokens: 128_000, released_on: "2026-04-23",
    description: "OpenAI's frontier model for complex professional workloads. 1M token context, text + image input, native computer use.",
    prices: [ { on: "2026-04-23", in: 5, out: 30, cached: 0.50, src: "openai.com/api/pricing" } ]
  },
  {
    provider: :openai, name: "GPT-5", tier: "frontier", status: "legacy",
    context_window: 1_000_000, max_output_tokens: nil, released_on: "2025-08-07",
    description: "Launched at commodity pricing ($1.25/$10) so low TechCrunch said it may spark a price war. Superseded by GPT-5.5.",
    prices: [ { on: "2025-08-07", in: 1.25, out: 10, cached: 0.125, src: "openai.com/api/pricing" } ]
  },
  {
    provider: :openai, name: "o3-pro", tier: "frontier", status: "active",
    context_window: 200_000, max_output_tokens: nil, released_on: "2025-06-10",
    description: "Premium high-compute reasoning variant launched alongside the 80% o3 price cut — 87% cheaper than the o1-pro it replaced.",
    prices: [ { on: "2025-06-10", in: 20, out: 80, src: "openai.com/api/pricing" } ]
  },
  {
    provider: :openai, name: "o3", tier: "frontier", status: "active",
    context_window: 200_000, max_output_tokens: nil, released_on: "2025-04-16",
    description: "OpenAI's frontier reasoning model. Received an 80% price cut in June 2025 alongside the o3-pro launch.",
    prices: [
      { on: "2025-04-16", in: 10, out: 40, cached: 2.50, src: "openai.com/api/pricing", note: "Launch pricing" },
      { on: "2025-06-10", in: 2, out: 8, cached: 0.50, src: "openai.com/api/pricing", note: "80% price cut alongside o3-pro launch" }
    ]
  },
  {
    provider: :openai, name: "GPT-4.1", tier: "mid", status: "active",
    context_window: 1_000_000, max_output_tokens: nil, released_on: "2025-04-14",
    description: "Workhorse text model with 1M context. Positioned between the budget GPT-5 and premium GPT-5.5.",
    prices: [ { on: "2025-04-14", in: 2, out: 8, cached: 0.50, src: "openai.com/api/pricing" } ]
  },
  {
    provider: :openai, name: "o4-mini", tier: "small", status: "active",
    context_window: 200_000, max_output_tokens: nil, released_on: "2025-04-16",
    description: "Cost-effective reasoning model with multimodal support. Replaced o3-mini at the same price point.",
    prices: [ { on: "2025-04-16", in: 1.10, out: 4.40, cached: 0.275, src: "openai.com/api/pricing" } ]
  },
  {
    provider: :openai, name: "GPT-4.1 Mini", tier: "small", status: "active",
    context_window: 1_000_000, max_output_tokens: nil, released_on: "2025-04-14",
    description: "Fast, cost-effective model with 1M context for high-volume workloads.",
    prices: [ { on: "2025-04-14", in: 0.40, out: 1.60, cached: 0.10, src: "openai.com/api/pricing" } ]
  },
  {
    provider: :openai, name: "GPT-4.1 Nano", tier: "small", status: "active",
    context_window: 1_000_000, max_output_tokens: nil, released_on: "2025-04-14",
    description: "Cheapest OpenAI model — designed for classification, routing, and high-throughput extraction.",
    prices: [ { on: "2025-04-14", in: 0.10, out: 0.40, cached: 0.025, src: "openai.com/api/pricing" } ]
  },
  {
    provider: :openai, name: "o3-mini", tier: "small", status: "retired",
    context_window: 200_000, max_output_tokens: nil, released_on: "2025-01-31",
    description: "Efficient reasoning model. Replaced by o4-mini at the same price point.",
    prices: [ { on: "2025-01-31", in: 1.10, out: 4.40, src: "openai.com/api/pricing" } ]
  },
  {
    provider: :openai, name: "GPT-4.5", tier: "frontier", status: "retired",
    context_window: 128_000, max_output_tokens: nil, released_on: "2025-02-27",
    description: "Brief ultra-premium experiment at $75/$150 — the most expensive API model ever offered. Quickly superseded.",
    prices: [ { on: "2025-02-27", in: 75, out: 150, src: "openai.com/api/pricing" } ]
  },
  {
    provider: :openai, name: "o1", tier: "frontier", status: "retired",
    context_window: 200_000, max_output_tokens: nil, released_on: "2024-12-17",
    description: "Full o1 release. Chain-of-thought tokens billed as output make effective costs 2–5× the list price.",
    prices: [ { on: "2024-12-17", in: 15, out: 60, src: "openai.com/api/pricing" } ]
  },
  {
    provider: :openai, name: "o1-mini", tier: "small", status: "retired",
    context_window: 128_000, max_output_tokens: nil, released_on: "2024-09-12",
    description: "Budget reasoning model at one-fifth of o1's price. Cut to o3-mini's $1.10/$4.40 when that model launched.",
    prices: [
      { on: "2024-09-12", in: 3, out: 12, src: "openai.com/api/pricing", note: "Launch pricing" },
      { on: "2025-01-31", in: 1.10, out: 4.40, src: "openai.com/api/pricing", note: "Repriced to match o3-mini at its launch; date corroborated by archived openai.com/api/pricing data model (updatedAt 2025-01-31T19:07:33Z)" }
    ]
  },
  {
    provider: :openai, name: "o1-preview", tier: "frontier", status: "retired",
    context_window: 128_000, max_output_tokens: nil, released_on: "2024-09-12",
    description: "First reasoning model — introduced chain-of-thought billing where thinking tokens are charged as output.",
    prices: [ { on: "2024-09-12", in: 15, out: 60, src: "openai.com/api/pricing" } ]
  },
  {
    provider: :openai, name: "GPT-4o mini", tier: "small", status: "retired",
    context_window: 128_000, max_output_tokens: nil, released_on: "2024-07-18",
    description: "Replaced GPT-3.5 Turbo at 60% lower cost with far better quality — ended the 3.5 era.",
    prices: [ { on: "2024-07-18", in: 0.15, out: 0.60, src: "openai.com/api/pricing" } ]
  },
  {
    provider: :openai, name: "GPT-4o", tier: "frontier", status: "retired",
    context_window: 128_000, max_output_tokens: nil, released_on: "2024-05-13",
    description: "Halved GPT-4 Turbo pricing with multimodal support. Received a 50% input price cut in August 2024.",
    prices: [
      { on: "2024-05-13", in: 5, out: 15, src: "openai.com/api/pricing", note: "Launch pricing" },
      { on: "2024-08-06", in: 2.50, out: 10, src: "openai.com/api/pricing", note: "50% input price cut" }
    ]
  },
  {
    provider: :openai, name: "GPT-4 Turbo", tier: "frontier", status: "retired",
    context_window: 128_000, max_output_tokens: nil, released_on: "2023-11-06",
    description: "3× cheaper than GPT-4 with 128K context. Preview Nov 2023, GA April 2024.",
    prices: [ { on: "2023-11-06", in: 10, out: 30, src: "openai.com/api/pricing" } ]
  },
  {
    provider: :openai, name: "GPT-4", tier: "frontier", status: "retired",
    context_window: 8_192, max_output_tokens: nil, released_on: "2023-03-14",
    description: "Set the frontier pricing baseline at $30/$60 — 10× more than GPT-3.5 Turbo. 32K variant was $60/$120.",
    prices: [ { on: "2023-03-14", in: 30, out: 60, src: "openai.com/api/pricing", note: "8K context; 32K variant was $60/$120" } ]
  },
  {
    provider: :openai, name: "GPT-3.5 Turbo", tier: "small", status: "retired",
    context_window: 16_385, max_output_tokens: nil, released_on: "2023-03-01",
    description: "The ChatGPT API model — *the* price-decline story, with three cuts in under a year taking it from $2/$2 to $0.50/$1.50. Replaced by GPT-4o mini in July 2024.",
    prices: [
      { on: "2023-03-01", in: 2, out: 2, src: "openai.com/pricing", note: "Launch at $0.002/1K tokens, flat across input and output" },
      { on: "2023-06-13", in: 1.50, out: 2, src: "openai.com/pricing", note: "25% input price cut" },
      { on: "2023-11-06", in: 1, out: 2, src: "openai.com/pricing", note: "gpt-3.5-turbo-1106, announced at DevDay" },
      { on: "2024-01-25", in: 0.50, out: 1.50, src: "openai.com/pricing", note: "gpt-3.5-turbo-0125 — third cut in a year" }
    ]
  },

  # ---- Google -----------------------------------------------------------
  {
    provider: :google, name: "Gemini 3.1 Pro", tier: "frontier", status: "active",
    context_window: 1_000_000, max_output_tokens: 64_000, released_on: "2026-02-19",
    description: "Google's frontier model. Context-tiered pricing: $2/$12 up to 200K tokens, $4/$18 beyond. Figures shown are the ≤200K tier.",
    prices: [ { on: "2026-02-19", in: 2, out: 12, cached: 0.20, src: "ai.google.dev/gemini-api/docs/pricing", note: "≤200K context tier" } ]
  },
  {
    provider: :google, name: "Gemini 3 Pro", tier: "frontier", status: "legacy",
    context_window: 1_000_000, max_output_tokens: 64_000, released_on: "2025-11-18",
    description: "Previous Gemini Pro generation with the same context-tiered pricing model. Superseded by Gemini 3.1 Pro.",
    prices: [ { on: "2025-11-18", in: 2, out: 12, cached: 0.20, src: "ai.google.dev/gemini-api/docs/pricing", note: "≤200K context tier" } ]
  },
  {
    provider: :google, name: "Gemini 2.5 Pro", tier: "frontier", status: "legacy",
    context_window: 1_000_000, max_output_tokens: 64_000, released_on: "2025-06-17",
    description: "First Gemini with native thinking/reasoning. Context-tiered: $1.25/$10 ≤200K, $2.50/$15 beyond.",
    prices: [
      { on: "2025-06-17", in: 1.25, out: 10, cached: 0.3125, src: "ai.google.dev/gemini-api/docs/pricing", note: "≤200K context tier; launch cached rate confirmed via Wayback capture 2025-06-21 ($0.31/MTok displayed, $0.625 for >200K)" },
      { on: "2025-10-09", in: 1.25, out: 10, cached: 0.125, src: "ai.google.dev/gemini-api/docs/pricing", note: "≤200K context tier; cached-input cut (in/out unchanged), bracketed by Wayback captures 2025-10-05 ($0.3125) → 2025-10-09 ($0.125)" }
    ]
  },
  {
    provider: :google, name: "Gemini 3.5 Flash", tier: "mid", status: "active",
    context_window: 1_000_000, max_output_tokens: 64_000, released_on: "2026-05-19",
    description: "Latest Flash model — 3× pricier than Gemini 3 Flash ($0.50/$3), signaling the end of ultra-cheap Flash pricing.",
    prices: [ { on: "2026-05-19", in: 1.5, out: 9, cached: 0.15, src: "ai.google.dev/gemini-api/docs/pricing" } ]
  },
  {
    provider: :google, name: "Gemini 3 Flash", tier: "mid", status: "legacy",
    context_window: 1_000_000, max_output_tokens: 64_000, released_on: "2025-12-17",
    description: "Cost-effective Flash model. Superseded by Gemini 3.5 Flash which tripled the price.",
    prices: [ { on: "2025-12-17", in: 0.50, out: 3, cached: 0.05, src: "ai.google.dev/gemini-api/docs/pricing" } ]
  },
  {
    provider: :google, name: "Gemini 2.5 Flash", tier: "mid", status: "legacy",
    context_window: 1_000_000, max_output_tokens: 64_000, released_on: "2025-06-17",
    description: "First Flash model with thinking. Flat pricing (no context tiers). Superseded by Gemini 3 Flash.",
    prices: [
      { on: "2025-06-17", in: 0.30, out: 2.50, cached: 0.075, src: "ai.google.dev/gemini-api/docs/pricing", note: "Launch cached rate confirmed via Wayback capture 2025-06-21" },
      { on: "2025-10-09", in: 0.30, out: 2.50, cached: 0.03, src: "ai.google.dev/gemini-api/docs/pricing", note: "Cached-input cut (in/out unchanged), bracketed by Wayback captures 2025-10-05 ($0.075) → 2025-10-09 ($0.03)" }
    ]
  },
  {
    provider: :google, name: "Gemini 2.0 Flash", tier: "mid", status: "retired",
    context_window: 1_000_000, max_output_tokens: nil, released_on: "2024-12-11",
    description: "Experimental then GA — very competitive at $0.10/$0.40, cheaper than GPT-4o mini.",
    prices: [ { on: "2024-12-11", in: 0.10, out: 0.40, src: "ai.google.dev/gemini-api/docs/pricing" } ]
  },
  {
    provider: :google, name: "Gemini 1.5 Pro", tier: "frontier", status: "retired",
    context_window: 1_000_000, max_output_tokens: nil, released_on: "2024-02-15",
    description: "Introduced the 1M-token context window. Launched at $7/$21; repriced twice to reach $1.25/$5 by late 2024.",
    prices: [
      { on: "2024-02-15", in: 7, out: 21, src: "ai.google.dev/gemini-api/docs/pricing", note: "Launch pricing" },
      { on: "2024-10-01", in: 1.25, out: 5, src: "ai.google.dev/gemini-api/docs/pricing", note: "Price cut to $1.25/$5 for ≤128K context tier" }
    ]
  },
  {
    provider: :google, name: "Gemini 1.5 Flash", tier: "mid", status: "retired",
    context_window: 1_000_000, max_output_tokens: nil, released_on: "2024-05-14",
    description: "Budget model with 1M context. Launched at $0.35/$1.05 at Google I/O; slashed 78% in August 2024 to undercut GPT-4o mini.",
    prices: [
      { on: "2024-05-14", in: 0.35, out: 1.05, src: "ai.google.dev/gemini-api/docs/pricing", note: "Launch pricing at Google I/O" },
      { on: "2024-08-12", in: 0.075, out: 0.30, src: "ai.google.dev/gemini-api/docs/pricing", note: "78% input price cut" }
    ]
  },
  {
    provider: :google, name: "Gemini 1.0 Pro", tier: "frontier", status: "retired",
    context_window: 32_000, max_output_tokens: nil, released_on: "2023-12-06",
    description: "Initial Gemini launch — competitive with GPT-3.5 Turbo at $0.50/$1.50.",
    prices: [ { on: "2023-12-06", in: 0.50, out: 1.50, src: "ai.google.dev/gemini-api/docs/pricing" } ]
  },

  # ---- xAI --------------------------------------------------------------
  {
    provider: :xai, name: "Grok 4.3", tier: "frontier", status: "active",
    context_window: 1_000_000, max_output_tokens: 64_000, released_on: "2026-04-30",
    description: "xAI's current flagship — aggressively priced for a frontier model, with a 1M token context window.",
    prices: [ { on: "2026-04-30", in: 1.25, out: 2.50, cached: 0.20, src: "docs.x.ai" } ]
  },
  {
    provider: :xai, name: "Grok 4.20", tier: "frontier", status: "legacy",
    context_window: 2_000_000, max_output_tokens: 64_000, released_on: "2026-03-10",
    description: "Predecessor to Grok 4.3 with 2M context. Later aligned to Grok 4.3 pricing.",
    prices: [
      { on: "2026-03-10", in: 2, out: 6, cached: 0.20, src: "openrouter.ai/x-ai/grok-4.20", note: "Launch pricing (OpenRouter; still $2/$6 at Wayback capture 2026-04-01)" },
      { on: "2026-05-12", in: 1.25, out: 2.50, cached: 0.20, src: "docs.x.ai", note: "Realigned to Grok 4.3 pricing; present by Wayback docs.x.ai capture 2026-05-12 (realignment bracketed 2026-04-01 → 2026-05-12)" }
    ]
  },
  {
    provider: :xai, name: "Grok 4", tier: "frontier", status: "retired",
    context_window: 256_000, max_output_tokens: 64_000, released_on: "2025-07-09",
    description: "Previous xAI flagship. Retired May 15, 2026; traffic redirected to Grok 4.3.",
    prices: [ { on: "2025-07-09", in: 3, out: 15, cached: 0.75, src: "docs.x.ai" } ]
  },
  {
    provider: :xai, name: "Grok Build 0.1", tier: "mid", status: "active",
    context_window: 256_000, max_output_tokens: nil, released_on: "2026-05-20",
    description: "xAI's coding-specialist model — cheaper than Grok 4.3 for code generation tasks.",
    prices: [ { on: "2026-05-20", in: 1, out: 2, cached: 0.20, src: "x.ai/news/grok-build-0-1" } ]
  },
  {
    provider: :xai, name: "Grok 4.1 Fast", tier: "small", status: "retired",
    context_window: 2_000_000, max_output_tokens: 64_000, released_on: "2025-11-19",
    description: "Low-cost, fast Grok variant with 2M context. Retired May 15, 2026; traffic redirected to Grok 4.3.",
    prices: [ { on: "2025-11-19", in: 0.20, out: 0.50, cached: 0.05, src: "docs.x.ai" } ]
  },
  {
    provider: :xai, name: "Grok 3 Mini", tier: "small", status: "retired",
    context_window: 128_000, max_output_tokens: nil, released_on: "2025-06-10",
    description: "Budget Grok at $0.30/$0.50 — undercut o1-mini by 10× on input. Superseded by Grok 4.1 Fast.",
    prices: [ { on: "2025-06-10", in: 0.30, out: 0.50, src: "docs.x.ai", note: "API availability date; model previewed Feb 2025" } ]
  },
  {
    provider: :xai, name: "Grok 3", tier: "frontier", status: "retired",
    context_window: 131_072, max_output_tokens: nil, released_on: "2025-04-09",
    description: "xAI's pre-Grok-4 flagship — established the $3/$15 price point that Grok 4 launched at. Fills the gap between Grok 2 and Grok 4.",
    prices: [ { on: "2025-04-09", in: 3, out: 15, src: "docs.x.ai", note: "API availability date (grok-3-beta); model previewed Feb 2025" } ]
  },
  {
    provider: :xai, name: "Grok 2", tier: "frontier", status: "retired",
    context_window: 128_000, max_output_tokens: nil, released_on: "2024-08-13",
    description: "xAI's first API model. The public API beta (grok-beta) charged $5/$15; the $2/$10 Grok pricing baseline arrived that December.",
    prices: [
      { on: "2024-10-21", in: 5, out: 15, src: "docs.x.ai", note: "Public API beta pricing (grok-beta); $5/$15 confirmed via Wayback docs.x.ai capture 2024-12-17 (coexisting with grok-2-1212); 2024-10-21 effective date remains approximate — no earlier price-table capture exists" },
      { on: "2024-12-12", in: 2, out: 10, src: "docs.x.ai", note: "Repriced with the grok-2-1212 release" }
    ]
  },

  # ---- DeepSeek ---------------------------------------------------------
  {
    provider: :deepseek, name: "DeepSeek V4 Pro", tier: "frontier", status: "active",
    context_window: 1_000_000, max_output_tokens: 384_000, released_on: "2026-04-24",
    description: "Open-weight frontier model. DeepSeek made a 75% promotional discount permanent in May 2026, making it one of the cheapest frontier models.",
    prices: [
      { on: "2026-04-24", in: 1.74, out: 3.48, cached: 0.0145, src: "api-docs.deepseek.com", note: "Launch pricing" },
      { on: "2026-05-22", in: 0.435, out: 0.87, cached: 0.003625, src: "engadget.com/deepseek-permanently-reduces-price", note: "75% promotional discount made permanent" }
    ]
  },
  {
    provider: :deepseek, name: "DeepSeek V4 Flash", tier: "mid", status: "active",
    context_window: 1_000_000, max_output_tokens: 384_000, released_on: "2026-04-24",
    description: "Ultra-cheap frontier-class model (284B total, 13B active MoE). Launched alongside V4 Pro.",
    prices: [ { on: "2026-04-24", in: 0.14, out: 0.28, cached: 0.0028, src: "api-docs.deepseek.com" } ]
  },
  {
    provider: :deepseek, name: "DeepSeek R1", tier: "frontier", status: "legacy",
    context_window: 128_000, max_output_tokens: nil, released_on: "2025-01-20",
    description: "Open-weight reasoning model that stunned the industry at launch. Repriced with V3.2-Exp in September 2025; now routes to V4 Flash thinking mode and is scheduled for deprecation July 2026.",
    prices: [
      { on: "2025-01-20", in: 0.55, out: 2.19, cached: 0.14, src: "api-docs.deepseek.com", note: "Launch pricing" },
      { on: "2025-09-29", in: 0.28, out: 0.42, cached: 0.028, src: "api-docs.deepseek.com", note: "V3.2-Exp repricing, applied to deepseek-reasoner as well as V3" }
    ]
  },
  {
    provider: :deepseek, name: "DeepSeek V3", tier: "mid", status: "legacy",
    context_window: 128_000, max_output_tokens: nil, released_on: "2024-12-26",
    description: "General-purpose chat model. Launched on a promotional $0.14/$0.28 (Dec 2024–Feb 2025), then settled at $0.27/$1.10; received a 50%+ output price cut with the V3.2-Exp update in September 2025.",
    prices: [
      { on: "2024-12-26", in: 0.14, out: 0.28, cached: 0.014, src: "api-docs.deepseek.com", note: "Launch promotional pricing (discounted from list $0.27/$1.10); confirmed via Wayback capture 2024-12-28; page-stated promo end 2025-02-08 16:00 UTC" },
      { on: "2025-02-09", in: 0.27, out: 1.10, cached: 0.07, src: "api-docs.deepseek.com", note: "Post-promotional pricing; cached-input $0.07 confirmed via Wayback capture 2025-02-17 (the seeded $0.027 was an error)" },
      { on: "2025-09-29", in: 0.28, out: 0.42, cached: 0.028, src: "api-docs.deepseek.com", note: "V3.2-Exp: 50%+ output price cut" }
    ]
  },
  {
    provider: :deepseek, name: "DeepSeek V2", tier: "mid", status: "retired",
    context_window: 128_000, max_output_tokens: nil, released_on: "2024-05-06",
    description: "Open-weight MoE whose ~$0.14/MTok input price triggered China's May 2024 LLM price war — Alibaba and Baidu slashed rates within weeks.",
    prices: [ { on: "2024-05-06", in: 0.14, out: 0.28, src: "api-docs.deepseek.com", note: "¥1/¥2 per MTok converted; confirmed first-party via Wayback platform.deepseek.com capture 2024-05-25 (deepseek-chat $0.14/$0.28)" } ]
  },

  # ---- Cohere -----------------------------------------------------------
  {
    provider: :cohere, name: "Command R Plus", tier: "frontier", status: "legacy",
    context_window: 128_000, max_output_tokens: nil, released_on: "2024-04-04",
    description: "Cohere's enterprise RAG flagship, marketed as Command R+. The August 2024 refresh cut pricing from $3/$15 to $2.50/$10.",
    prices: [
      { on: "2024-04-04", in: 3, out: 15, src: "cohere.com/pricing", note: "Launch pricing" },
      { on: "2024-08-30", in: 2.50, out: 10, src: "docs.cohere.com/changelog/command-gets-refreshed", note: "Pricing of the new command-r-plus-08-2024 version; the 04-2024 model kept launch pricing" }
    ]
  },
  {
    provider: :cohere, name: "Command R", tier: "mid", status: "legacy",
    context_window: 128_000, max_output_tokens: nil, released_on: "2024-03-11",
    description: "Cohere's scalable RAG and tool-use workhorse. The August 2024 refresh cut input pricing 70% to $0.15/$0.60.",
    prices: [
      { on: "2024-03-11", in: 0.50, out: 1.50, src: "cohere.com/pricing", note: "Launch pricing" },
      { on: "2024-08-30", in: 0.15, out: 0.60, src: "docs.cohere.com/changelog/command-gets-refreshed", note: "Pricing of the new command-r-08-2024 version (70% input cut); the 03-2024 model kept launch pricing" }
    ]
  },

  # ---- Open-weight models (hosted prices vary by provider) --------------
  {
    provider: :meta, name: "Llama 4 Maverick", tier: "frontier", status: "active",
    context_window: 1_000_000, max_output_tokens: nil, released_on: "2025-04-05",
    description: "Meta's open-weight MoE flagship (17B active / 400B+ total). Hosted pricing varies widely; figures are a representative hosted rate.",
    prices: [ { on: "2025-04-05", in: 0.15, out: 0.60, src: "pricepertoken.com", note: "Representative hosted rate; varies by provider" } ]
  },
  {
    provider: :meta, name: "Llama 4 Scout", tier: "mid", status: "active",
    context_window: 1_000_000, max_output_tokens: nil, released_on: "2025-04-05",
    description: "Meta's smaller open-weight MoE model (17B active / 109B total). Supports up to 10M context on some providers.",
    prices: [ { on: "2025-04-05", in: 0.08, out: 0.30, src: "pricepertoken.com", note: "Representative hosted rate (DeepInfra); varies by provider" } ]
  },
  {
    provider: :meta, name: "Llama 3.3 70B", tier: "mid", status: "retired",
    context_window: 128_000, max_output_tokens: nil, released_on: "2024-12-06",
    description: "Late-2024 70B refresh delivering near-405B quality at 70B serving cost — the open-weight reference rate going into 2025.",
    prices: [ { on: "2024-12-06", in: 0.59, out: 0.79, src: "pricepertoken.com", note: "Representative hosted rate (Groq); varies by provider" } ]
  },
  {
    provider: :meta, name: "Llama 3.1 405B", tier: "frontier", status: "retired",
    context_window: 128_000, max_output_tokens: nil, released_on: "2024-07-23",
    description: "Largest open-weight model at launch — GPT-4-class quality that anchored hosted pricing expectations lower.",
    prices: [ { on: "2024-07-23", in: 3, out: 3, src: "pricepertoken.com", note: "Representative hosted rate (Together AI); varies by provider" } ]
  },
  {
    provider: :meta, name: "Llama 3 70B", tier: "mid", status: "retired",
    context_window: 8_192, max_output_tokens: nil, released_on: "2024-04-18",
    description: "Meta's first widely hosted open-weight model — pushed hosted LLM pricing below $1/MTok.",
    prices: [ { on: "2024-04-18", in: 0.59, out: 0.79, src: "pricepertoken.com", note: "Representative hosted rate (Together/Fireworks); varies by provider" } ]
  },

  {
    provider: :mistral, name: "Mistral Medium 3.5", tier: "mid", status: "active",
    context_window: 128_000, max_output_tokens: nil, released_on: "2026-04-29",
    description: "Consolidated model folding Medium 3.1, Magistral reasoning, and Devstral 2 into one set of weights with a per-request reasoning toggle.",
    prices: [ { on: "2026-04-29", in: 1.50, out: 7.50, src: "mistral.ai/pricing" } ]
  },
  {
    provider: :mistral, name: "Mistral Large 3", tier: "frontier", status: "active",
    context_window: 262_000, max_output_tokens: nil, released_on: "2025-12-02",
    description: "Mistral's Apache-2.0 open-weight frontier model (675B total / 41B active MoE). 75% cheaper than Large 2 at $0.50/$1.50.",
    prices: [ { on: "2025-12-02", in: 0.50, out: 1.50, src: "mistral.ai/pricing" } ]
  },
  {
    provider: :mistral, name: "Mistral Small 4", tier: "small", status: "active",
    context_window: 262_000, max_output_tokens: nil, released_on: "2026-03-16",
    description: "Fast, cost-effective model for high-volume and latency-sensitive workloads. Launched at $0.15/$0.60, later cut to $0.10/$0.30.",
    prices: [
      { on: "2026-03-16", in: 0.15, out: 0.60, src: "mistral.ai/pricing", note: "Launch pricing (corroborated by 2026 pricing trackers)" },
      { on: "2026-06-03", in: 0.10, out: 0.30, src: "mistral.ai/pricing", note: "Price cut to $0.10/$0.30 confirmed on Wayback capture 2026-06-03; exact cut date unpinnable (launch-era mistral.ai/pricing captures are JS shells), bracketed [2026-03-16, 2026-06-03]" }
    ]
  },
  {
    provider: :mistral, name: "Mistral Large 2", tier: "frontier", status: "retired",
    context_window: 128_000, max_output_tokens: nil, released_on: "2024-07-24",
    description: "Launched at $3/$9 — a deep cut from Large v1's $8/$24 — then cut again to $2/$6 that September. Superseded by Large 3 at 75% lower cost.",
    prices: [
      { on: "2024-07-24", in: 3, out: 9, src: "mistral.ai/pricing", note: "Launch pricing" },
      { on: "2024-09-17", in: 2, out: 6, src: "mistral.ai/news/september-24-release", note: "September 2024 price cut" }
    ]
  },
  {
    provider: :mistral, name: "Mistral Large", tier: "frontier", status: "retired",
    context_window: 32_000, max_output_tokens: nil, released_on: "2024-02-26",
    description: "Mistral's initial flagship at $8/$24, cut to $4/$12 in early May 2024. Superseded by Large 2 that July.",
    prices: [
      { on: "2024-02-26", in: 8, out: 24, src: "mistral.ai/pricing", note: "Launch list price (USD)" },
      { on: "2024-05-05", in: 4, out: 12, src: "mistral.ai/technology/#pricing", note: "50% cut; bracketed by Wayback captures 2024-04-25 ($8/$24) → 2024-05-05 ($4/$12), earlier than LiteLLM's late-May window" }
    ]
  },
  {
    provider: :mistral, name: "Mixtral 8x7B", tier: "mid", status: "retired",
    context_window: 32_768, max_output_tokens: nil, released_on: "2023-12-11",
    description: "Apache-2.0 MoE that put GPT-3.5-class quality in open weights, setting a price floor under proprietary small models. Figures are Mistral's own API rate.",
    prices: [ { on: "2024-02-26", in: 0.70, out: 0.70, src: "mistral.ai/pricing", note: "USD list rate from the Au Large release, which renamed mistral-small to open-mixtral-8x7b and introduced USD pricing; the Dec 2023 endpoint was EUR-priced" } ]
  },
  {
    provider: :mistral, name: "Mistral 7B", tier: "small", status: "retired",
    context_window: 32_768, max_output_tokens: nil, released_on: "2023-09-27",
    description: "Mistral's first open-weight model, served as the cheapest endpoint on La Plateforme from December 2023. Figures are Mistral's own API rate.",
    prices: [ { on: "2024-02-26", in: 0.25, out: 0.25, src: "mistral.ai/pricing", note: "USD list rate from the Au Large release (mistral-tiny became open-mistral-7b); the Dec 2023 endpoint was EUR-priced and not flat" } ]
  },
  {
    provider: :alibaba, name: "Qwen 3.7 Max", tier: "frontier", status: "active",
    context_window: 1_000_000, max_output_tokens: nil, released_on: "2026-05-20",
    description: "Alibaba's latest flagship Qwen model with 1M context, announced at Alibaba Cloud Summit.",
    prices: [ { on: "2026-05-20", in: 2.50, out: 7.50, src: "codersera.com/blog/qwen-3-7-max-launch-guide-2026", note: "List price; 50% promotional discount available; date approximate" } ]
  },
  {
    provider: :alibaba, name: "Qwen3 Max", tier: "frontier", status: "legacy",
    context_window: 256_000, max_output_tokens: nil, released_on: "2025-09-23",
    description: "Alibaba's previous flagship. Received a 50% price cut in November 2025 as China's AI price war intensified.",
    prices: [
      { on: "2025-09-23", in: 0.86, out: 3.44, src: "alibabacloud.com/help/en/model-studio/model-pricing", note: "DashScope launch pricing" },
      { on: "2025-11-14", in: 0.46, out: 1.84, src: "scmp.com", note: "50% price cut in China's AI price war" },
      { on: "2026-06-01", in: 0.36, out: 1.43, src: "alibabacloud.com/help/en/model-studio/model-pricing", note: "Further cut to $0.359/$1.434 (Chinese-mainland base ≤32K tier); date approximate — bracketed [2026-01-16, 2026-06-01] by Wayback captures, undocumented elsewhere" }
    ]
  },
  {
    provider: :moonshot, name: "Kimi K2.6", tier: "frontier", status: "active",
    context_window: 256_000, max_output_tokens: nil, released_on: "2026-04-20",
    description: "Moonshot AI's latest open-weight frontier model with 300-agent swarm support.",
    prices: [ { on: "2026-04-20", in: 0.95, out: 4.00, cached: 0.16, src: "platform.moonshot.ai", note: "Direct API rate confirmed via Wayback capture of platform.moonshot.ai 2026-04-27 (Cache Hit $0.16 / Input $0.95 / Output $4.00 per MTok)" } ]
  },
  {
    provider: :moonshot, name: "Kimi K2.5", tier: "frontier", status: "legacy",
    context_window: 256_000, max_output_tokens: nil, released_on: "2026-01-27",
    description: "Multimodal model with Agent Swarm technology. Superseded by K2.6.",
    prices: [ { on: "2026-01-27", in: 0.60, out: 3.00, cached: 0.10, src: "platform.moonshot.ai", note: "Direct API rate confirmed via Wayback capture of platform.moonshot.ai 2026-04-02 (Cache Hit $0.10 / Input $0.60 / Output $3.00 per MTok)" } ]
  },
  {
    provider: :moonshot, name: "Kimi K2", tier: "frontier", status: "retired",
    context_window: 128_000, max_output_tokens: nil, released_on: "2025-07-11",
    description: "Moonshot's first open-weight frontier model (1T total / 32B active MoE). End-of-life May 25, 2026.",
    prices: [ { on: "2025-07-11", in: 0.55, out: 2.20, cached: 0.15, src: "pricepertoken.com" } ]
  },

  # ---- Image generation (directory-first) -------------------------------
  # Priced per image, not per token — that native price is curated separately
  # and isn't tracked yet, so these carry no price points. They classify as
  # image_generation via their output modality and list under the "Image
  # generation" category. See docs/IMAGE_CATEGORY_PLAN.md.
  {
    provider: :openai, name: "GPT Image 1", tier: "frontier", status: "active",
    context_window: nil, max_output_tokens: nil, released_on: "2025-04-23",
    description: "OpenAI's natively multimodal image model, exposed through the Images and Responses APIs. Takes text and image input and returns generated or edited images. Billed per image (by size and quality).",
    input_modalities: %w[image text], output_modalities: %w[image],
    prices: []
  },
  {
    provider: :google, name: "Imagen 4", tier: "frontier", status: "active",
    context_window: nil, max_output_tokens: nil, released_on: "2025-05-20",
    description: "Google's text-to-image model, available through the Gemini API and Vertex AI. Billed per generated image.",
    input_modalities: %w[text], output_modalities: %w[image],
    prices: []
  },
  {
    provider: :black_forest_labs, name: "FLUX.1 [pro]", tier: "frontier", status: "active",
    context_window: nil, max_output_tokens: nil, released_on: "2024-08-01",
    description: "Black Forest Labs' flagship text-to-image model, served through their API and several inference providers. Billed per generated image.",
    input_modalities: %w[text], output_modalities: %w[image],
    prices: []
  },
  {
    provider: :stability, name: "Stable Diffusion 3.5 Large", tier: "mid", status: "active",
    context_window: nil, max_output_tokens: nil, released_on: "2024-10-22",
    description: "Stability AI's 8B-parameter text-to-image model, available through the Stability API and as open weights. Billed per generated image on the hosted API.",
    input_modalities: %w[text], output_modalities: %w[image],
    prices: []
  }
]

# ---------------------------------------------------------------------------
# Editorial — qualitative "what it's for" copy, keyed by slug.
#
# Kept separate from the price-bearing catalog above because it changes on a
# different cadence: a model's strengths and use-cases are stable even as its
# price moves. The show page pairs this with always-computed price insights, so
# nothing here needs to mention dollars — that stays accurate on its own.
# ---------------------------------------------------------------------------
editorial = {
  "claude-fable-5" => {
    strengths: "Top-end reasoning and long-horizon agentic autonomy — the most capable model in the catalogue.",
    best_for: "The hardest research, coding and multi-step agent tasks where capability outweighs cost.",
    limitations: "Access is currently suspended; also the most expensive option and overkill for routine or high-volume work."
  },
  "claude-opus-4-8" => {
    strengths: "Highly autonomous on long agentic and knowledge work, with a 1M-token context at standard pricing.",
    best_for: "Complex coding, deep research and agent workflows that run for many steps.",
    limitations: "Premium Opus pricing — a Sonnet-tier model is usually enough for everyday tasks."
  },
  "claude-opus-4-7" => {
    strengths: "Strong autonomous agentic, vision and memory performance at the same price as 4.8.",
    best_for: "Teams already integrated on 4.7 that don't yet need the latest Opus.",
    limitations: "Superseded by Opus 4.8, which improves quality at no extra cost."
  },
  "claude-opus-4-6" => {
    strengths: "First Opus with a 1M-token window, at the post-cut Opus price.",
    best_for: "Long-context Opus work where the newest releases aren't required.",
    limitations: "Older Opus generation; later versions improve quality at the same price."
  },
  "claude-opus-4-5" => {
    strengths: "Landmark release that cut Opus pricing 67%, with capable frontier reasoning.",
    best_for: "Workloads happy on a 200K context that want proven Opus quality.",
    limitations: "200K context and an older generation; surpassed by the 4.6+ line."
  },
  "claude-opus-4-1" => {
    strengths: "Refined Opus 4 with incremental quality gains at the same price.",
    best_for: "Legacy integrations pinned to the pre-cut Opus line.",
    limitations: "An older, pricier Opus generation fully superseded by the post-4.5 line."
  },
  "claude-opus-4" => {
    strengths: "The original Claude 4 flagship; strong general reasoning for its era.",
    best_for: "Reproducing results from the original Claude 4 launch.",
    limitations: "Expensive early pricing, fully superseded by cheaper, better Opus releases."
  },
  "claude-sonnet-4-6" => {
    strengths: "The best speed-to-intelligence balance in the line, with a 1M-token context.",
    best_for: "Production apps, coding assistants and agents that need quality without Opus prices.",
    limitations: "Not as deep as Opus on the very hardest reasoning tasks."
  },
  "claude-sonnet-4-5" => {
    strengths: "Capable mid-tier Sonnet at the durable Sonnet price.",
    best_for: "General-purpose work where the newest Sonnet isn't essential.",
    limitations: "Superseded by Sonnet 4.6 at identical pricing."
  },
  "claude-sonnet-4" => {
    strengths: "Set the Sonnet price point that held across the whole 4.x line.",
    best_for: "Legacy Sonnet integrations.",
    limitations: "Older generation; newer Sonnets are better at the same price."
  },
  "claude-haiku-4-5" => {
    strengths: "Fastest and cheapest Claude, with prompt-cache savings for repeated context.",
    best_for: "High-volume classification, routing, extraction and latency-sensitive features.",
    limitations: "Lighter reasoning than Sonnet or Opus; not for the hardest tasks."
  },
  "gpt-5-5-pro" => {
    strengths: "OpenAI's highest-accuracy reasoning variant.",
    best_for: "Mission-critical analysis where answer quality outweighs latency and cost.",
    limitations: "Slowest and priciest GPT-5.5 tier; wasteful for simple prompts."
  },
  "gpt-5-5" => {
    strengths: "Frontier multimodal model with a 1M-token context and native computer use.",
    best_for: "Complex professional workloads spanning text, images and tool use.",
    limitations: "Frontier pricing stepped up from GPT-5's commodity rates."
  },
  "gpt-5" => {
    strengths: "Frontier-class quality at near-commodity pricing.",
    best_for: "Cost-sensitive general workloads that still want a capable model.",
    limitations: "Positioned below GPT-5.5 on capability."
  },
  "o3" => {
    strengths: "Strong dedicated step-by-step reasoning.",
    best_for: "Math, logic and multi-step problem solving.",
    limitations: "Reasoning-focused; the GPT-5 line now covers most of its ground."
  },
  "gpt-4-1" => {
    strengths: "Reliable 1M-context workhorse between the budget and premium tiers.",
    best_for: "Long-document processing and general text tasks at moderate cost.",
    limitations: "Previous generation; GPT-5 offers more for less."
  },
  "o4-mini" => {
    strengths: "Affordable reasoning with multimodal support.",
    best_for: "Budget reasoning tasks and high-volume problem solving.",
    limitations: "Smaller reasoning model; less capable than the full o-series or GPT-5.5."
  },
  "gpt-4-1-mini" => {
    strengths: "Fast and cheap with a full 1M-token context.",
    best_for: "High-volume text processing and long-context summarisation on a budget.",
    limitations: "Mini-class quality; not for complex reasoning."
  },
  "gpt-4-1-nano" => {
    strengths: "OpenAI's cheapest model, tuned for raw throughput.",
    best_for: "Classification, routing and high-throughput extraction.",
    limitations: "Minimal reasoning ability; strictly for simple, well-scoped tasks."
  },
  "gemini-3-1-pro" => {
    strengths: "Google's frontier model with very long context and competitive entry pricing.",
    best_for: "Long-context analysis and multimodal work in the Google ecosystem.",
    limitations: "Context-tiered pricing rises above 200K tokens, so cost scales with prompt size."
  },
  "gemini-3-pro" => {
    strengths: "Capable previous-generation Pro with the same context-tiered model.",
    best_for: "Existing Gemini Pro integrations not yet moved to 3.1.",
    limitations: "Superseded by Gemini 3.1 Pro."
  },
  "gemini-2-5-pro" => {
    strengths: "First Gemini with native reasoning, at a low entry-tier price.",
    best_for: "Reasoning tasks on a budget within the Gemini family.",
    limitations: "Older generation; pricing scales up beyond a 200K context."
  },
  "gemini-3-5-flash" => {
    strengths: "Fast Flash-tier model with improved quality.",
    best_for: "High-volume tasks that still want Gemini quality and speed.",
    limitations: "Much pricier than Gemini 3 Flash — the ultra-cheap Flash era is over."
  },
  "gemini-3-flash" => {
    strengths: "Cheap, fast Flash model built for scale.",
    best_for: "High-throughput, latency-sensitive workloads on a tight budget.",
    limitations: "Superseded by 3.5 Flash; lighter reasoning than Pro."
  },
  "gemini-2-5-flash" => {
    strengths: "First Flash with reasoning, at flat (non-tiered) pricing.",
    best_for: "Budget reasoning at high volume.",
    limitations: "Older Flash generation; surpassed by Gemini 3 Flash."
  },
  "grok-4-3" => {
    strengths: "Aggressively priced frontier flagship with a 1M-token context.",
    best_for: "Cost-conscious frontier workloads and real-time, X-integrated use.",
    limitations: "Ecosystem and tooling less mature than the largest labs."
  },
  "grok-4-20" => {
    strengths: "Huge 2M-token context, later aligned to Grok 4.3 pricing.",
    best_for: "Very long-context tasks that exceed a 1M window.",
    limitations: "Superseded by Grok 4.3."
  },
  "grok-4" => {
    strengths: "A former xAI flagship with strong general reasoning for its generation.",
    best_for: "Reference only — traffic now redirects to Grok 4.3.",
    limitations: "Retired May 2026; no longer served directly."
  },
  "grok-build-0-1" => {
    strengths: "Coding-specialist model priced below Grok 4.3 for code generation.",
    best_for: "Code generation and developer-tool integrations.",
    limitations: "Narrowly tuned for coding; not a general-purpose chat model."
  },
  "grok-4-1-fast" => {
    strengths: "Fast, low-cost variant with a 2M-token context.",
    best_for: "High-volume, long-context tasks where speed and price lead.",
    limitations: "Retired May 2026; traffic redirected to Grok 4.3."
  },
  "deepseek-v4-pro" => {
    strengths: "Open-weight frontier quality at one of the lowest prices anywhere, with deep cached-input discounts.",
    best_for: "Cost-sensitive frontier workloads and self-hosting on open weights.",
    limitations: "Smaller ecosystem and tooling than the major US labs."
  },
  "deepseek-v4-flash" => {
    strengths: "Ultra-cheap frontier-class MoE (284B total / 13B active).",
    best_for: "High-volume tasks needing near-frontier quality at minimal cost.",
    limitations: "Lighter than V4 Pro; trades some quality for price."
  },
  "deepseek-r1" => {
    strengths: "Landmark open reasoning model that reset industry price expectations.",
    best_for: "Reasoning experiments and reference work on open weights.",
    limitations: "Now routes to V4 Flash thinking mode; scheduled for deprecation July 2026."
  },
  "deepseek-v3" => {
    strengths: "Capable general-purpose open chat model at very low cost.",
    best_for: "Everyday chat and text tasks on a tight budget.",
    limitations: "Older generation; the V4 line is stronger and similarly priced."
  },
  "llama-4-maverick" => {
    strengths: "Open-weight MoE flagship (17B active / 400B+ total) you can self-host or buy hosted.",
    best_for: "Teams that want open weights with frontier-adjacent quality.",
    limitations: "Hosted pricing varies widely by provider; the figure shown is representative."
  },
  "llama-4-scout" => {
    strengths: "Smaller open MoE supporting up to a 10M-token context on some hosts.",
    best_for: "Extreme long-context tasks and budget self-hosting.",
    limitations: "Lighter than Maverick; hosted pricing and context limits vary by provider."
  },
  "mistral-medium-3-5" => {
    strengths: "One set of weights folding chat, reasoning and code with a per-request reasoning toggle.",
    best_for: "Mixed workloads that want reasoning on demand without switching models.",
    limitations: "Mid-tier capability; not aimed at the absolute frontier."
  },
  "mistral-large-3" => {
    strengths: "Apache-2.0 open-weight frontier MoE (675B total / 41B active).",
    best_for: "Open-weight frontier deployments and permissive-license self-hosting.",
    limitations: "Trails the very top closed models on the hardest tasks."
  },
  "mistral-small-4" => {
    strengths: "Fast, cheap model for high-volume and latency-sensitive work.",
    best_for: "Scaled text processing, routing and simple assistants.",
    limitations: "Small-tier quality; not for complex reasoning."
  },
  "qwen-3-7-max" => {
    strengths: "Alibaba's latest flagship with a 1M-token context.",
    best_for: "Long-context and multilingual work, especially Chinese-language tasks.",
    limitations: "Western tooling and integrations less mature."
  },
  "qwen3-max" => {
    strengths: "Capable previous Qwen flagship with long-context, multilingual strengths.",
    best_for: "Budget multilingual and long-context tasks.",
    limitations: "Superseded by Qwen 3.7 Max."
  },
  "kimi-k2-6" => {
    strengths: "Open-weight frontier model with large agent-swarm support at a low direct-API rate.",
    best_for: "Agentic, multi-tool workflows on open weights at low cost.",
    limitations: "Hosted providers may charge well above the direct rate."
  },
  "kimi-k2-5" => {
    strengths: "Multimodal model with Agent Swarm support.",
    best_for: "Multimodal agent workflows not yet moved to K2.6.",
    limitations: "Superseded by Kimi K2.6."
  },
  "kimi-k2" => {
    strengths: "Moonshot's first open-weight frontier model (1T total / 32B active MoE).",
    best_for: "Reference only.",
    limitations: "End-of-life May 25, 2026."
  }
}

# ---------------------------------------------------------------------------
# Persist
# ---------------------------------------------------------------------------
# Fail loudly if an editorial entry's slug doesn't match a catalog model — a
# renamed model or typo'd key would otherwise silently drop its copy via the
# fetch default below.
orphaned_editorial = editorial.keys - catalog.map { |row| row[:name].parameterize }
raise "Editorial copy references unknown model slug(s): #{orphaned_editorial.join(', ')}" if orphaned_editorial.any?

catalog.each do |row|
  model = AiModel.find_or_initialize_by(slug: row[:name].parameterize)
  copy = editorial.fetch(row[:name].parameterize, {})
  attrs = {
    provider:          providers.fetch(row[:provider]),
    name:              row[:name],
    tier:              row[:tier],
    status:            row[:status],
    context_window:    row[:context_window],
    max_output_tokens: row[:max_output_tokens],
    released_on:       row[:released_on],
    description:       row[:description],
    strengths:         copy[:strengths],
    best_for:          copy[:best_for],
    limitations:       copy[:limitations]
  }
  # Only image-gen (and future directory) rows carry an explicit signature;
  # text models omit it and keep the [] default that derives modality_class :text.
  attrs[:input_modalities]  = row[:input_modalities]  if row[:input_modalities]
  attrs[:output_modalities] = row[:output_modalities] if row[:output_modalities]
  model.update!(**attrs)

  wanted_dates = row[:prices].map { |p| Date.parse(p[:on]) }
  # Keep the seed declarative: drop snapshots that are no longer listed
  # (e.g. when a launch date is corrected) so re-seeding can't leave phantoms.
  model.price_points.where.not(effective_on: wanted_dates).destroy_all

  row[:prices].each do |p|
    point = model.price_points.find_or_initialize_by(effective_on: Date.parse(p[:on]))
    point.update!(
      input_per_mtok:        p[:in],
      output_per_mtok:       p[:out],
      cached_input_per_mtok: p[:cached],
      source:                p[:src],
      note:                  p[:note]
    )
  end
end

# ---------------------------------------------------------------------------
# Market Events — curated industry milestones for Trends overlays
# ---------------------------------------------------------------------------
market_events = [
  { title: "GPT-4 sets the frontier price", event_date: "2023-03-14",
    note: "GPT-4 launches at $30/$60 per MTok — 10× the cost of GPT-3.5 Turbo, establishing the first frontier pricing baseline." },
  { title: "GPT-4 Turbo: 3× cheaper", event_date: "2023-11-06",
    note: "GPT-4 Turbo launches at $10/$30 with 128K context, cutting the frontier price by two-thirds and kicking off a year of rapid cuts." },
  { title: "Mixtral 8x7B goes open-weight", event_date: "2023-12-11",
    note: "Mistral releases Mixtral 8x7B under Apache 2.0 — GPT-3.5-class quality anyone can host, setting a price floor under proprietary small models." },
  { title: "OpenAI cuts GPT-3.5 Turbo 50%", event_date: "2024-01-25",
    note: "Third GPT-3.5 Turbo cut in a year: input drops 50% to $0.50/1M, output 25% to $1.50. New embedding models arrive 5x cheaper too." },
  { title: "Gemini 1.5 Pro: 1M context", event_date: "2024-02-15",
    note: "Google announces a 1M-token context window, an order of magnitude beyond rivals — long context becomes a $/token battleground." },
  { title: "Claude 3 brings $0.25 Haiku", event_date: "2024-03-04",
    note: "The Claude 3 family ships with Haiku at $0.25/$1.25 per 1M, staking out the fast-and-cheap tier against GPT-3.5 Turbo." },
  { title: "GPT-4o: frontier at half price", event_date: "2024-05-13",
    note: "GPT-4o launches at $5/$15 per 1M — half of GPT-4 Turbo's price with better performance, resetting the frontier price bar." },
  { title: "China's LLM price war erupts", event_date: "2024-05-21",
    note: "After DeepSeek-V2 launched at ~$0.14/1M input on May 6, Alibaba cuts Qwen prices up to 97% and Baidu makes Ernie Speed/Lite free hours later." },
  { title: "Claude 3.5 Sonnet resets value", event_date: "2024-06-20",
    note: "Anthropic ships a model beating Opus at one-fifth Opus's price ($3/$15), collapsing the gap between mid-tier price and frontier quality." },
  { title: "GPT-4o mini at $0.15", event_date: "2024-07-18",
    note: "OpenAI replaces GPT-3.5 Turbo with GPT-4o mini at $0.15/$0.60 per 1M — over 60% cheaper and far more capable." },
  { title: "Llama 3.1 405B opens frontier", event_date: "2024-07-23",
    note: "Meta releases a GPT-4-class model as open weights; hosted 405B undercuts proprietary frontier pricing and anchors expectations lower." },
  { title: "OpenAI cuts GPT-4o 50%", event_date: "2024-08-06",
    note: "GPT-4o input drops $5→$2.50/1M and prompt caching arrives — the first big frontier price war shot." },
  { title: "Google slashes Flash 78%", event_date: "2024-08-12",
    note: "Gemini 1.5 Flash drops 78% on input / 71% on output to $0.075/$0.30 per 1M, undercutting GPT-4o mini by half." },
  { title: "Anthropic ships prompt caching", event_date: "2024-08-14",
    note: "Cached input tokens cost 90% less on Claude, making long-system-prompt and RAG workloads dramatically cheaper." },
  { title: "o1 creates reasoning price tier", event_date: "2024-09-12",
    note: "OpenAI's o1-preview launches at $15/$60 — a new pricing category where chain-of-thought tokens make effective costs 2–5× the list price." },
  { title: "Gemini 1.5 Pro cut 64%", event_date: "2024-10-01",
    note: "Google cuts Gemini 1.5 Pro to $1.25/$5.00 per 1M on prompts under 128K — the flagship tier joins the price war." },
  { title: "OpenAI caching: auto 50% off", event_date: "2024-10-01",
    note: "DevDay brings automatic prompt caching — a no-code 50% discount on recently seen input tokens across GPT-4o and o1 models." },
  { title: "DeepSeek V3: frontier for cents", event_date: "2024-12-26",
    note: "DeepSeek releases a GPT-4o-class open model priced around $0.27/$1.10 per 1M, previewing the shock R1 would deliver a month later." },
  { title: "The DeepSeek moment", event_date: "2025-01-20",
    note: "DeepSeek R1 ships near-frontier reasoning at ~1/20th the price. Markets jolt; pricing pressure spikes industry-wide." },
  { title: "GPT-4.5: ultra-premium experiment", event_date: "2025-02-27",
    note: "OpenAI tests $75/$150 pricing with GPT-4.5 — the most expensive API model ever offered. Quickly superseded by cheaper, better models." },
  { title: "Long-context goes cheap", event_date: "2025-04-14",
    note: "GPT-4.1 lands a 1M-token window at mid-tier pricing, matching Gemini on context economics." },
  { title: "o3 price cut 80%", event_date: "2025-06-10",
    note: "OpenAI slashes o3 by 80% ($10→$2/1M input), making frontier reasoning mainstream-affordable." },
  { title: "GPT-5 sparks price war", event_date: "2025-08-07",
    note: "GPT-5 launches at commodity pricing ($1.25/$10) — TechCrunch calls it a price-war trigger." },
  { title: "Qwen3 Max halved in price war", event_date: "2025-11-14",
    note: "Alibaba cuts Qwen3 Max roughly 50% as China's AI price war reignites, pressuring domestic and global rivals alike." },
  { title: "Opus gets 67% cheaper", event_date: "2025-11-24",
    note: "Anthropic drops Opus pricing from $15/$75 to $5/$25 with the Opus 4.5 release." },
  { title: "Mistral Large 3: 75% cheaper", event_date: "2025-12-02",
    note: "Mistral's open-weight frontier flagship lands at $0.50/$1.50 per 1M — 75% below Large 2 — keeping open-model pressure on closed pricing." },
  { title: "GPT-5.5 raises frontier prices", event_date: "2026-04-23",
    note: "GPT-5.5 launches at $5/$30 per 1M, a sharp step up from GPT-5's commodity pricing — frontier labs begin testing price tolerance." },
  { title: "Cheap Flash era ends", event_date: "2026-05-19",
    note: "Gemini 3.5 Flash ships at $1.50/$9 per 1M — triple its predecessor — as Google reprices Flash from budget tier toward Pro territory." },
  { title: "DeepSeek V4 Pro 75% cut", event_date: "2026-05-22",
    note: "DeepSeek makes a 75% promotional discount permanent, pricing V4 Pro at $0.435/$0.87." }
]

market_events.each do |attrs|
  MarketEvent.find_or_initialize_by(event_date: Date.parse(attrs[:event_date]), title: attrs[:title]).tap do |e|
    e.update!(kind: "market", note: attrs[:note])
  end
end

puts "Seeded #{Provider.count} providers, #{AiModel.count} models, #{PricePoint.count} price points, #{MarketEvent.count} market events."
