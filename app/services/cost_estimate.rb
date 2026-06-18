# The single-workload cost engine — a faithful Ruby port of the design
# prototype's pure `window.COST` (cost-engine.js). All money math lives here,
# server-side and tested; the controller renders the result into a Turbo Frame.
#
# A workload profile drives everything:
#   { sys, fresh, out, req, cache, tier, base, summary }
#   sys   — system/reused tokens repeated each call (cacheable)
#   fresh — new input tokens per request
#   out   — output tokens per request
#   req   — requests per month
#   cache — cache hit-rate %, 0..95 (share of `sys` served from cache)
#   tier  — minimum capability floor: any | small | mid | frontier
#   base  — baseline model slug to compare against
#
# Structured so a list of steps can slot in later (the measure-&-optimize
# product) — V1 prices exactly one workload.
class CostEstimate
  DEFAULT = {
    sys: 1800, fresh: 240, out: 380, req: 450_000,
    cache: 70, tier: "frontier", base: "gpt-4o", summary: ""
  }.freeze

  TIERS = %w[any small mid frontier].freeze

  # An immutable workload. `total_tokens` is what must fit a model's context.
  Profile = Data.define(:sys, :fresh, :out, :req, :cache, :tier, :base, :summary) do
    def total_tokens = sys + fresh + out

    # The canonical, shareable/indexable query params for this workload.
    def to_query
      { sys:, fresh:, out:, req:, cache:, tier:, base:,
        summary: summary.presence }.compact
    end
  end

  # One model priced for the workload. Predicates mirror the design fields.
  Row = Data.define(:entry, :per_req, :in_cost, :out_cost, :cache_saved,
                    :monthly, :fits, :eligible, :has_cache, :delta) do
    def fits? = fits
    def eligible? = eligible
    def has_cache? = has_cache
    def slug = entry.slug
  end

  Hint = Data.define(:icon, :title, :body, :save)

  attr_reader :profile

  def initialize(profile, models: nil)
    @profile = profile.is_a?(Profile) ? profile : self.class.profile_from(profile)
    @models  = models || PriceCatalog.models
  end

  # ---- ranking helpers (ported) ----
  def self.tier_rank(t) = { "small" => 1, "mid" => 2, "frontier" => 3 }[t] || 0
  # capability floor: any/small → 1, mid → 2, frontier → 3
  def self.floor_rank(t) = t == "frontier" ? 3 : t == "mid" ? 2 : 1

  # Per-request cost components for an explicit set of rates, given the workload.
  # Cached input applies the hit rate to the `sys` tokens: hits bill at the
  # model's cached rate, misses at full input. Fresh input never caches.
  def price_with(input:, output:, cached:, prof: profile)
    hit = prof.cache / 100.0
    cache_rate = cached || input
    in_fresh  = (prof.fresh / 1e6) * input
    in_cached = (prof.sys / 1e6) * ((hit * cache_rate) + ((1 - hit) * input))
    out_cost  = (prof.out / 1e6) * output
    no_cache_in = ((prof.fresh + prof.sys) / 1e6) * input
    {
      per_req: in_fresh + in_cached + out_cost,
      in_cost: in_fresh + in_cached,
      out_cost: out_cost,
      cache_saved: [ 0.0, (no_cache_in + out_cost) - (in_fresh + in_cached + out_cost) ].max
    }
  end

  # Price one catalog entry for the workload (without the baseline delta).
  def price_model(entry, prof: profile)
    r = price_with(input: entry.input, output: entry.output, cached: entry.cached, prof: prof)
    Row.new(
      entry: entry,
      per_req: r[:per_req], in_cost: r[:in_cost], out_cost: r[:out_cost],
      cache_saved: r[:cache_saved],
      monthly: r[:per_req] * prof.req,
      fits: entry.ctx.nil? || entry.ctx >= prof.total_tokens,
      eligible: prof.tier == "any" || self.class.tier_rank(entry.tier) >= self.class.floor_rank(prof.tier),
      has_cache: !entry.cached.nil?,
      delta: nil
    )
  end

  # Every model priced for this workload, cheapest monthly first, each row
  # carrying its % delta vs the baseline.
  def rows
    @rows ||= begin
      priced = @models.map { |e| price_model(e) }.sort_by(&:monthly)
      base_monthly = (priced.find { |r| r.slug == profile.base } || priced.first)&.monthly
      priced.map do |r|
        delta = if base_monthly.nil? || r.slug == profile.base then nil
        else CostFormat.pct(r.monthly, base_monthly)
        end
        r.with(delta: delta)
      end
    end
  end

  # Cheapest row that both fits the context and meets the capability floor —
  # the "cheapest equivalent."
  def recommendation
    @recommendation ||= rows.find { |r| r.fits? && r.eligible? }
  end

  # The row for the baseline slug, falling back to the cheapest overall when the
  # requested baseline isn't in the catalog (reconciles unknown/mock slugs).
  def baseline
    @baseline ||= rows.find { |r| r.slug == profile.base } || rows.first
  end

  # Baseline already optimal?
  def same?
    recommendation && baseline && recommendation.slug == baseline.slug
  end

  # Monthly/%/yearly delta of switching baseline → recommendation.
  def savings
    return nil unless recommendation && baseline

    monthly = baseline.monthly - recommendation.monthly
    {
      monthly: monthly,
      pct: CostFormat.pct(recommendation.monthly, baseline.monthly),
      yearly: monthly * 12
    }
  end

  def total_tokens = profile.total_tokens

  # This workload priced on the cheapest fitting+eligible model at each historical
  # price-change date — the "priced through history" sparkline series, ascending.
  def retrospective
    @retrospective ||= begin
      dates = (PriceCatalog.change_dates + [ Date.current ]).uniq.sort
      min_rank = self.class.floor_rank(profile.tier)
      dates.filter_map do |d|
        best = nil
        @models.each do |e|
          next unless e.ctx.nil? || e.ctx >= profile.total_tokens
          next unless profile.tier == "any" || self.class.tier_rank(e.tier) >= min_rank

          snap = e.as_of(d)
          next unless snap

          monthly = price_with(input: snap.input, output: snap.output, cached: snap.cached)[:per_req] * profile.req
          best = { date: d, monthly: monthly, slug: e.slug } if best.nil? || monthly < best[:monthly]
        end
        best
      end
    end
  end

  # 2–3 contextual cost-cutting tips for this workload (ported).
  def strategy_hints
    r = recommendation
    out = []
    denom = r ? (r.in_cost + r.out_cost) : 0
    out_share = r && denom.positive? ? r.out_cost / denom : 0

    if r && r.has_cache? && profile.sys > 600
      lift = [ 95, profile.cache + 25 ].min
      now    = price_model(r.entry).monthly
      better = price_model(r.entry, prof: profile.with(cache: lift)).monthly
      save = profile.cache < lift && (now - better) > 0.5 ? "≈ #{CostFormat.money(now - better)}/mo at #{lift}% hit" : nil
      out << Hint.new(icon: "cache", title: "Cache the context",
        body: "You reuse #{CostFormat.kfmt(profile.sys)} context tokens each call. Cached input bills up to 90% cheaper.",
        save: save)
    end

    if out_share > 0.5
      trimmed = price_model(r.entry, prof: profile.with(out: (profile.out * 0.7).round)).monthly
      out << Hint.new(icon: "scissors", title: "Trim outputs",
        body: "Output is #{(out_share * 100).round}% of this bill — billed 3–5× input. Tighter answers move it most.",
        save: "≈ #{CostFormat.money(r.monthly - trimmed)}/mo at −30% length")
    end

    out << Hint.new(icon: "route", title: "Route by difficulty",
      body: "Send easy calls to a small model and reserve a frontier model for the hard ones. A 70/30 split often halves spend.",
      save: nil)
    out << Hint.new(icon: "bolt", title: "Use the Batch API",
      body: "Non-urgent jobs (eval, backfill, summarization) run ~50% cheaper on async batch endpoints.",
      save: "≈ −50% on batchable volume")

    out.first(3)
  end

  # ---- profile construction ----

  # Build a clamped Profile from a params-ish hash (string or symbol keys),
  # falling back to DEFAULT for anything missing or out of range.
  def self.profile_from(raw)
    raw = raw.to_h.symbolize_keys
    tier = TIERS.include?(raw[:tier].to_s) ? raw[:tier].to_s : DEFAULT[:tier]
    Profile.new(
      sys:   clamp(raw[:sys],   0, 2_000_000,     DEFAULT[:sys]),
      fresh: clamp(raw[:fresh], 0, 2_000_000,     DEFAULT[:fresh]),
      out:   clamp(raw[:out],   0, 2_000_000,     DEFAULT[:out]),
      req:   clamp(raw[:req],   1, 5_000_000_000, DEFAULT[:req]),
      cache: clamp(raw[:cache], 0, 95,            DEFAULT[:cache]),
      tier:  tier,
      base:  raw[:base].present? ? raw[:base].to_s : DEFAULT[:base],
      summary: raw[:summary].to_s[0, 60]
    )
  end

  # Heuristic describe-in-a-sentence fill (ported). No LLM on the critical path:
  # the estimator never hard-depends on a model call.
  def self.heuristic_fill(desc)
    d = desc.to_s.downcase
    req = 100_000
    if (m = d.match(/([\d,.]+)\s*(k|m|million|thousand)?\s*(chats?|requests?|tickets?|calls?|users?|articles?|docs?|documents?|runs?|queries|conversations?)\s*(?:per|\/|a)\s*(day|month|hour|week)?/))
      n = m[1].delete(",").to_f
      n *= 1_000     if m[2].to_s.match?(/k|thousand/)
      n *= 1_000_000 if m[2].to_s.match?(/m|million/)
      case m[4]
      when "day"  then n *= 30
      when "hour" then n *= 720
      when "week" then n *= 4.3
      end
      req = n.round
    end
    rag    = d.match?(/docs?|knowledge|help ?center|rag|context|manual|policy/)
    code   = d.match?(/cod(e|ing)|agent|debug|engineer|software|repo|refactor/)
    simple = d.match?(/classif|extract|summari|tag|label|route|moderat/)
    {
      sys:   rag ? 4000 : code ? 2500 : 800,
      fresh: code ? 1200 : simple ? 600 : 200,
      out:   code ? 900 : simple ? 80 : 350,
      cache: rag ? 80 : 50,
      req:   req,
      tier:  code ? "frontier" : simple ? "small" : "mid",
      summary: desc.to_s[0, 56],
      base:  code ? "gpt-4o" : simple ? "gpt-4o-mini" : "gpt-4o"
    }
  end

  def self.clamp(value, lo, hi, default)
    v = value.to_s.strip
    return default if v.empty?

    n = Integer(v.to_f.round) rescue nil
    return default if n.nil?

    n.clamp(lo, hi)
  end
  private_class_method :clamp
end
