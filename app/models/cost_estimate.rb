# The per-call cost primitive — a faithful Ruby port of the design prototype's
# pure money math. All cost math lives here, server-side and tested.
#
# Scope after the /cost estimator and model-page embed were removed: this is now
# consumed only by FeaturePattern::Cost, which needs exactly `price_with`, a `Profile`
# (built via `profile_from`), and their internals. The ranking/recommendation/
# retrospective/strategy surface those callers used is gone.
#
# A workload profile drives the math:
#   sys   — system/reused tokens repeated each call (cacheable)
#   fresh — new input tokens per request
#   out   — output tokens per request
#   req   — requests per month
#   cache — cache hit-rate %, 0..95 (share of `sys` served from cache)
#   tier  — minimum capability floor: any | small | mid | frontier
#   base  — baseline model slug to compare against
class CostEstimate
  DEFAULT = {
    sys: 1800, fresh: 240, out: 380, req: 450_000,
    cache: 70, tier: "frontier", base: "gpt-4o", summary: ""
  }.freeze

  TIERS = %w[any small mid frontier].freeze

  # An immutable workload.
  Profile = Data.define(:sys, :fresh, :out, :req, :cache, :tier, :base, :summary)

  attr_reader :profile

  def initialize(profile, models: nil)
    @profile = profile.is_a?(Profile) ? profile : self.class.profile_from(profile)
    @models  = models || PriceCatalog.models
  end

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

  def self.clamp(value, lo, hi, default)
    v = value.to_s.strip
    return default if v.empty?

    # Float() raises on non-numeric input (unlike to_f), so garbage params fall
    # back to the default rather than silently collapsing to the lower bound.
    num = begin
      Float(v)
    rescue ArgumentError, TypeError
      nil
    end
    return default if num.nil?

    num.round.clamp(lo, hi)
  end
  private_class_method :clamp
end
