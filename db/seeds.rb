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
  anthropic: { name: "Anthropic", website: "https://www.anthropic.com", accent: "#D97757" },
  openai:    { name: "OpenAI",    website: "https://openai.com",        accent: "#10A37F" },
  google:    { name: "Google",    website: "https://ai.google.dev",     accent: "#4285F4" },
  xai:       { name: "xAI",        website: "https://x.ai",              accent: "#1F2937" },
  deepseek:  { name: "DeepSeek",  website: "https://www.deepseek.com",  accent: "#4D6BFE" },
  meta:      { name: "Meta",      website: "https://www.llama.com",     accent: "#0866FF" },
  mistral:   { name: "Mistral",   website: "https://mistral.ai",        accent: "#FA520F" },
  alibaba:   { name: "Alibaba",   website: "https://qwen.ai",           accent: "#615CED" },
  moonshot:  { name: "Moonshot AI", website: "https://www.moonshot.ai", accent: "#2D2A6E" }
}.transform_values do |attrs|
  Provider.find_or_create_by!(slug: attrs[:name].parameterize) do |p|
    p.assign_attributes(attrs)
  end.tap { |p| p.update!(attrs.slice(:website, :accent)) }
end

# ---------------------------------------------------------------------------
# Models + dated price history
#
# Each model: tier (frontier|mid|small), status (active|legacy|retired), context
# window, max output, release date, and a `prices` array of dated snapshots.
# ---------------------------------------------------------------------------
catalog = [
  # ---- Anthropic --------------------------------------------------------
  {
    provider: :anthropic, name: "Claude Fable 5", tier: "frontier", status: "active",
    context_window: 1_000_000, max_output_tokens: 128_000, released_on: "2026-06-09",
    description: "Anthropic's most powerful model — a new Mythos-class tier above Opus, aimed at the hardest reasoning and agentic work.",
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
    description: "Launched at commodity pricing ($0.625/$5) so low TechCrunch said it may spark a price war. Superseded by GPT-5.5.",
    prices: [ { on: "2025-08-07", in: 0.625, out: 5, cached: 0.0625, src: "openai.com/api/pricing" } ]
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
    prices: [ { on: "2025-06-17", in: 1.25, out: 10, cached: 0.125, src: "ai.google.dev/gemini-api/docs/pricing", note: "≤200K context tier" } ]
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
    prices: [ { on: "2025-06-17", in: 0.30, out: 2.50, cached: 0.03, src: "ai.google.dev/gemini-api/docs/pricing" } ]
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
    prices: [ { on: "2026-03-10", in: 2, out: 6, cached: 0.20, src: "openrouter.ai/x-ai/grok-4.20" } ]
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
    description: "Open-weight reasoning model that stunned the industry at launch. Now routes to V4 Flash thinking mode; scheduled for deprecation July 2026.",
    prices: [ { on: "2025-01-20", in: 0.55, out: 2.19, cached: 0.14, src: "api-docs.deepseek.com" } ]
  },
  {
    provider: :deepseek, name: "DeepSeek V3", tier: "mid", status: "legacy",
    context_window: 128_000, max_output_tokens: nil, released_on: "2024-12-26",
    description: "General-purpose chat model. Received a 50%+ output price cut with the V3.2-Exp update in September 2025.",
    prices: [
      { on: "2025-02-09", in: 0.27, out: 1.10, cached: 0.027, src: "api-docs.deepseek.com", note: "Post-promotional pricing" },
      { on: "2025-09-29", in: 0.28, out: 0.42, cached: 0.028, src: "api-docs.deepseek.com", note: "V3.2-Exp: 50%+ output price cut" }
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
    description: "Fast, cost-effective model for high-volume and latency-sensitive workloads.",
    prices: [ { on: "2026-03-16", in: 0.15, out: 0.60, src: "mistral.ai/pricing" } ]
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
      { on: "2025-11-14", in: 0.46, out: 1.84, src: "scmp.com", note: "50% price cut in China's AI price war" }
    ]
  },
  {
    provider: :moonshot, name: "Kimi K2.6", tier: "frontier", status: "active",
    context_window: 256_000, max_output_tokens: nil, released_on: "2026-04-20",
    description: "Moonshot AI's latest open-weight frontier model with 300-agent swarm support. Direct-API rate shown; some providers charge up to $0.95/$4.00.",
    prices: [ { on: "2026-04-20", in: 0.60, out: 2.50, cached: 0.15, src: "platform.moonshot.ai", note: "Direct API rate; hosted providers may charge more" } ]
  },
  {
    provider: :moonshot, name: "Kimi K2.5", tier: "frontier", status: "legacy",
    context_window: 256_000, max_output_tokens: nil, released_on: "2026-01-27",
    description: "Multimodal model with Agent Swarm technology. Superseded by K2.6.",
    prices: [ { on: "2026-01-27", in: 0.60, out: 2.50, cached: 0.10, src: "platform.moonshot.ai", note: "Direct API rate" } ]
  },
  {
    provider: :moonshot, name: "Kimi K2", tier: "frontier", status: "retired",
    context_window: 128_000, max_output_tokens: nil, released_on: "2025-07-11",
    description: "Moonshot's first open-weight frontier model (1T total / 32B active MoE). End-of-life May 25, 2026.",
    prices: [ { on: "2025-07-11", in: 0.55, out: 2.20, cached: 0.15, src: "pricepertoken.com" } ]
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
    limitations: "The most expensive option; overkill for routine or high-volume work."
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
  model.update!(
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
  )

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
  { title: "Gemini 1.5 Pro cut 64%", event_date: "2024-09-24",
    note: "Google cuts Gemini 1.5 Pro to $1.25/$5.00 per 1M on prompts under 128K — the flagship tier joins the price war." },
  { title: "OpenAI caching: auto 50% off", event_date: "2024-10-01",
    note: "DevDay brings automatic prompt caching — a no-code 50% discount on recently seen input tokens across GPT-4o and o1 models." },
  { title: "DeepSeek V3: frontier for cents", event_date: "2024-12-26",
    note: "DeepSeek releases a GPT-4o-class open model priced around $0.27/$1.10 per 1M, previewing the shock R1 would deliver a month later." },
  { title: "The DeepSeek moment", event_date: "2025-01-20",
    note: "DeepSeek R1 ships near-frontier reasoning at ~1/20th the price. Markets jolt; pricing pressure spikes industry-wide." },
  { title: "Long-context goes cheap", event_date: "2025-04-14",
    note: "GPT-4.1 lands a 1M-token window at mid-tier pricing, matching Gemini on context economics." },
  { title: "o3 price cut 80%", event_date: "2025-06-10",
    note: "OpenAI slashes o3 by 80% ($10→$2/1M input), making frontier reasoning mainstream-affordable." },
  { title: "GPT-5 sparks price war", event_date: "2025-08-07",
    note: "GPT-5 launches at commodity pricing ($0.625/$5) — TechCrunch calls it a price-war trigger." },
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
