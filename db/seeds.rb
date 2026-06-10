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
    prices: [ { on: "2025-06-17", in: 1.25, out: 10, cached: 0.13, src: "ai.google.dev/gemini-api/docs/pricing", note: "≤200K context tier" } ]
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
    context_window: 128_000, max_output_tokens: nil, released_on: "2025-12-02",
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
    context_window: 256_000, max_output_tokens: nil, released_on: "2026-05-21",
    description: "Alibaba's latest flagship Qwen model, announced at Alibaba Cloud Summit.",
    prices: [ { on: "2026-05-21", in: 2.50, out: 7.50, src: "codersera.com/blog/qwen-3-7-max-launch-guide-2026", note: "List price; 50% promotional discount available" } ]
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
    description: "Moonshot AI's latest open-weight frontier model with 300-agent swarm support. Direct-API rate shown; hosted providers differ.",
    prices: [ { on: "2026-04-20", in: 0.60, out: 2.50, cached: 0.15, src: "platform.moonshot.ai", note: "Direct API rate" } ]
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
# Persist
# ---------------------------------------------------------------------------
catalog.each do |row|
  model = AiModel.find_or_initialize_by(slug: row[:name].parameterize)
  model.update!(
    provider:          providers.fetch(row[:provider]),
    name:              row[:name],
    tier:              row[:tier],
    status:            row[:status],
    context_window:    row[:context_window],
    max_output_tokens: row[:max_output_tokens],
    released_on:       row[:released_on],
    description:       row[:description]
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

puts "Seeded #{Provider.count} providers, #{AiModel.count} models, #{PricePoint.count} price points."
