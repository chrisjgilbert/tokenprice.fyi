require "test_helper"

class CostEstimateTest < ActiveSupport::TestCase
  # LOCK: the per-call pricing primitive the Guide feature consumes directly,
  # tested controller-free with explicit rates and a representative per-call
  # token shape. The standalone /cost page and the model-page embed are gone;
  # this math must survive and stand alone. Expected figures are computed by
  # hand from the formula.
  test "price_with returns the per-call cost from explicit rates, independent of monthly req" do
    # Per-call token shape {sys, fresh, out, cache}: 2000 reused (cacheable)
    # system tokens, 300 fresh input, 500 output, 80% cache hit rate.
    profile = CostEstimate.profile_from(
      sys: 2000, fresh: 300, out: 500, req: 123_456, cache: 80, tier: "any"
    )
    est = CostEstimate.new(profile, models: [])

    # Explicit USD-per-1M rates for the model under test.
    input  = 3.0
    output = 15.0
    cached = 0.30

    r = est.price_with(input: input, output: output, cached: cached)

    # By hand, from the formula in CostEstimate#price_with:
    #   in_fresh  = (300  / 1e6) * 3.0                       = 0.0009
    #   in_cached = (2000 / 1e6) * (0.8*0.30 + 0.2*3.0)      = (0.002)*(0.84) = 0.00168
    #   out_cost  = (500  / 1e6) * 15.0                      = 0.0075
    expected_in_fresh  = (300 / 1e6) * input
    expected_in_cached = (2000 / 1e6) * ((0.8 * cached) + (0.2 * input))
    expected_out  = (500 / 1e6) * output
    expected_in   = expected_in_fresh + expected_in_cached
    expected_per  = expected_in + expected_out

    assert_in_delta 0.0009, expected_in_fresh, 1e-12  # anchors the hand-math
    assert_in_delta 0.00168, expected_in_cached, 1e-12
    assert_in_delta 0.0075, expected_out, 1e-12

    assert_in_delta expected_in,  r[:in_cost],  1e-12
    assert_in_delta expected_out, r[:out_cost], 1e-12
    assert_in_delta expected_per, r[:per_req],  1e-12
    assert_in_delta 0.01008, r[:per_req], 1e-9  # 0.0009 + 0.00168 + 0.0075

    # The per-call figure is a property of the token shape and rates alone — it
    # does not depend on monthly volume. A different `req` yields the same per_req.
    other = CostEstimate.new(profile.with(req: 1), models: [])
    assert_in_delta r[:per_req], other.price_with(input: input, output: output, cached: cached)[:per_req], 1e-12
  end

  test "cache blending bills hits at the cached rate and reports the saving" do
    # Cache hit rate is capped at 95% (faithful to the design), so 95% of the 1M
    # sys tokens bill at $0.50/1M and 5% at the full $5/1M input rate.
    profile = CostEstimate.profile_from(sys: 1_000_000, fresh: 0, out: 0, req: 1, cache: 95, tier: "any")
    r = CostEstimate.new(profile, models: []).price_with(input: 5.0, output: 0.0, cached: 0.5)

    assert_in_delta (0.95 * 0.5) + (0.05 * 5.0), r[:per_req], 0.0001 # 0.725
    assert_in_delta 5.0 - 0.725, r[:cache_saved], 0.0001            # vs $5 uncached
  end

  test "profile_from clamps out-of-range values and defaults blanks" do
    p = CostEstimate.profile_from(sys: -50, cache: 250, req: "", tier: "bogus", out: "900")

    assert_equal 0, p.sys                       # clamped up to the floor
    assert_equal 95, p.cache                     # clamped to the ceiling
    assert_equal CostEstimate::DEFAULT[:req], p.req # blank → default
    assert_equal CostEstimate::DEFAULT[:tier], p.tier # invalid → default
    assert_equal 900, p.out
  end

  test "profile_from falls back to defaults for non-numeric params, not the lower bound" do
    p = CostEstimate.profile_from(req: "abc", sys: "lots", out: "12.7")

    assert_equal CostEstimate::DEFAULT[:req], p.req # garbage → default, not 1
    assert_equal CostEstimate::DEFAULT[:sys], p.sys # garbage → default, not 0
    assert_equal 13, p.out                           # "12.7" rounds to 13
  end
end
