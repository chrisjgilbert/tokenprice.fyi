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
    context_window: 1_000_000, max_output_tokens: 128_000, released_on: nil,
    description: "Anthropic's most powerful model — a new tier above Opus, aimed at the hardest reasoning and agentic work.",
    prices: [ { on: "2026-05-28", in: 10, out: 50, cached: 1.0, src: "anthropic.com/pricing", note: "List price" } ]
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
    description: "Older Opus generation with adaptive thinking and a 1M context window.",
    prices: [ { on: "2026-02-05", in: 5, out: 25, cached: 0.50, src: "anthropic.com/pricing" } ]
  },
  {
    provider: :anthropic, name: "Claude Sonnet 4.6", tier: "mid", status: "active",
    context_window: 1_000_000, max_output_tokens: 64_000, released_on: nil,
    description: "Anthropic's best balance of speed and intelligence. 1M context window.",
    prices: [ { on: "2026-02-05", in: 3, out: 15, cached: 0.30, src: "anthropic.com/pricing", note: "Date approximate" } ]
  },
  {
    provider: :anthropic, name: "Claude Sonnet 4.5", tier: "mid", status: "legacy",
    context_window: 1_000_000, max_output_tokens: 64_000, released_on: "2025-09-29",
    description: "Previous Sonnet generation. Same $3 / $15 pricing as 4.6 — Sonnet pricing has held flat.",
    prices: [ { on: "2025-09-29", in: 3, out: 15, cached: 0.30, src: "anthropic.com/pricing" } ]
  },
  {
    provider: :anthropic, name: "Claude Haiku 4.5", tier: "small", status: "active",
    context_window: 200_000, max_output_tokens: 64_000, released_on: "2025-10-01",
    description: "Fastest and most cost-effective Claude model for simple, latency-sensitive tasks.",
    prices: [ { on: "2025-10-01", in: 1, out: 5, cached: 0.10, src: "anthropic.com/pricing" } ]
  },

  # ---- OpenAI -----------------------------------------------------------
  {
    provider: :openai, name: "GPT-5.5", tier: "frontier", status: "active",
    context_window: 1_000_000, max_output_tokens: 128_000, released_on: "2026-04-23",
    description: "OpenAI's frontier model for complex professional workloads. 1M token context, text + image input, native computer use.",
    prices: [ { on: "2026-04-23", in: 5, out: 30, cached: 0.50, src: "openai.com/api/pricing" } ]
  },
  {
    provider: :openai, name: "GPT-5.5 Pro", tier: "frontier", status: "active",
    context_window: 1_000_000, max_output_tokens: 128_000, released_on: "2026-04-24",
    description: "Highest-accuracy reasoning variant of GPT-5.5.",
    prices: [ { on: "2026-04-24", in: 30, out: 180, src: "openai.com/api/pricing" } ]
  },

  # ---- Google -----------------------------------------------------------
  {
    provider: :google, name: "Gemini 3.1 Pro", tier: "frontier", status: "active",
    context_window: 1_000_000, max_output_tokens: 64_000, released_on: nil,
    description: "Google's frontier model. Context-tiered pricing: $2 / $12 up to 200K tokens, $4 / $18 beyond. Figures shown are the ≤200K tier.",
    prices: [ { on: "2026-03-01", in: 2, out: 12, src: "ai.google.dev/gemini-api/docs/pricing", note: "≤200K context tier; date approximate" } ]
  },
  {
    provider: :google, name: "Gemini 3 Pro", tier: "frontier", status: "legacy",
    context_window: 1_000_000, max_output_tokens: 64_000, released_on: nil,
    description: "Previous Gemini Pro generation with the same context-tiered pricing model.",
    prices: [ { on: "2026-01-01", in: 2, out: 12, src: "ai.google.dev/gemini-api/docs/pricing", note: "≤200K context tier; date approximate" } ]
  },
  {
    provider: :google, name: "Gemini 3.5 Flash", tier: "mid", status: "active",
    context_window: 1_000_000, max_output_tokens: 64_000, released_on: "2026-05-19",
    description: "Cost-effective, fast Gemini model for high-volume workloads.",
    prices: [ { on: "2026-05-19", in: 1.5, out: 9, src: "ai.google.dev/gemini-api/docs/pricing" } ]
  },

  # ---- xAI --------------------------------------------------------------
  {
    provider: :xai, name: "Grok 4.3", tier: "frontier", status: "active",
    context_window: 1_000_000, max_output_tokens: 64_000, released_on: "2026-04-30",
    description: "xAI's current flagship — aggressively priced for a frontier model, with a 1M token context window.",
    prices: [ { on: "2026-04-30", in: 1.25, out: 2.50, src: "docs.x.ai" } ]
  },
  {
    provider: :xai, name: "Grok 4", tier: "frontier", status: "legacy",
    context_window: 256_000, max_output_tokens: 64_000, released_on: nil,
    description: "Previous xAI flagship.",
    prices: [ { on: "2025-12-01", in: 3, out: 15, src: "docs.x.ai", note: "Date approximate" } ]
  },
  {
    provider: :xai, name: "Grok 4.1 Fast", tier: "small", status: "active",
    context_window: 2_000_000, max_output_tokens: 64_000, released_on: nil,
    description: "Low-cost, fast Grok variant for high-throughput use, with a 2M token context window.",
    prices: [ { on: "2026-03-01", in: 0.20, out: 0.50, cached: 0.05, src: "docs.x.ai", note: "Date approximate" } ]
  },

  # ---- DeepSeek ---------------------------------------------------------
  {
    provider: :deepseek, name: "DeepSeek V4 Pro", tier: "frontier", status: "active",
    context_window: 1_000_000, max_output_tokens: 384_000, released_on: "2026-02-01",
    description: "Open-weight frontier model. In May 2026 DeepSeek made a 75% price cut permanent, dropping it to one of the cheapest frontier models available.",
    prices: [
      { on: "2026-02-01", in: 1.74, out: 3.48, cached: 0.0145, src: "api-docs.deepseek.com", note: "Launch / pre-cut pricing" },
      { on: "2026-05-31", in: 0.435, out: 0.87, cached: 0.003625, src: "deepseek.ai/blog", note: "75% permanent price cut" }
    ]
  },

  # ---- Open-weight models (hosted prices vary by provider) --------------
  {
    provider: :meta, name: "Llama 4 Maverick", tier: "frontier", status: "active",
    context_window: 1_000_000, max_output_tokens: nil, released_on: nil,
    description: "Meta's open-weight MoE flagship. Inexpensive but hosted pricing varies widely by provider; figures are a representative hosted rate.",
    prices: [ { on: "2026-01-01", in: 0.15, out: 0.60, src: "pricepertoken.com", note: "Representative hosted rate; varies by provider" } ]
  },
  {
    provider: :mistral, name: "Mistral Large 3", tier: "frontier", status: "active",
    context_window: 256_000, max_output_tokens: nil, released_on: nil,
    description: "Mistral's Apache-2.0 open-weight frontier model.",
    prices: [ { on: "2026-01-01", in: 2, out: 6, src: "mistral.ai/pricing", note: "Date approximate" } ]
  },
  {
    provider: :alibaba, name: "Qwen3 Max", tier: "frontier", status: "active",
    context_window: 256_000, max_output_tokens: nil, released_on: "2025-09-01",
    description: "Alibaba's flagship Qwen model — strong frontier performance at low cost.",
    prices: [ { on: "2025-09-01", in: 0.78, out: 3.90, src: "pricepertoken.com", note: "Date approximate" } ]
  },
  {
    provider: :moonshot, name: "Kimi K2.6", tier: "frontier", status: "active",
    context_window: 256_000, max_output_tokens: nil, released_on: "2026-04-01",
    description: "Moonshot AI's open-weight frontier model. Direct-API rate shown; hosted providers differ.",
    prices: [ { on: "2026-04-01", in: 0.55, out: 2.65, src: "platform.moonshot.ai", note: "Direct API rate; date approximate" } ]
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
