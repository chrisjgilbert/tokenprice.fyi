require "test_helper"

class CostEstimateTest < ActiveSupport::TestCase
  # A pure 1M-fresh-input request makes per-request cost equal to the input
  # rate, so the maths is easy to verify by hand.
  def estimate(overrides = {})
    profile = CostEstimate.profile_from(CostEstimate::DEFAULT.merge(overrides))
    CostEstimate.new(profile)
  end

  test "prices a model from input/output/cached rates" do
    est = estimate(sys: 0, fresh: 1_000_000, out: 0, req: 1, cache: 0, tier: "any")
    opus = est.rows.find { |r| r.slug == "claude-opus-4-8" }

    assert_in_delta 5.0, opus.per_req, 0.0001 # 1M tokens × $5/1M
    assert_in_delta 5.0, opus.monthly, 0.0001 # × 1 request
  end

  test "cache blending bills hits at the cached rate and reports the saving" do
    # Cache hit rate is capped at 95% (faithful to the design), so 95% of the 1M
    # sys tokens bill at $0.50/1M and 5% at the full $5/1M input rate.
    est = estimate(sys: 1_000_000, fresh: 0, out: 0, req: 1, cache: 95, tier: "any")
    opus = est.rows.find { |r| r.slug == "claude-opus-4-8" }

    assert_in_delta (0.95 * 0.5) + (0.05 * 5.0), opus.per_req, 0.0001 # 0.725
    assert_in_delta 5.0 - 0.725, opus.cache_saved, 0.0001              # vs $5 uncached
  end

  test "rows are sorted cheapest monthly first" do
    monthlies = estimate(tier: "any").rows.map(&:monthly)
    assert_equal monthlies.sort, monthlies
  end

  test "recommendation is the cheapest fitting and eligible model" do
    est = estimate(tier: "any", base: "claude-opus-4-8")
    fitting = est.rows.select { |r| r.fits? && r.eligible? }

    assert_equal fitting.first.slug, est.recommendation.slug
    # DeepSeek is by far the cheapest of the priced fixtures.
    assert_equal "deepseek-v4-pro", est.recommendation.slug
  end

  test "savings compares the baseline against the recommendation" do
    est = estimate(tier: "any", base: "claude-opus-4-8")

    refute est.same?
    assert_operator est.savings[:monthly], :>, 0
    assert_operator est.savings[:pct], :<, 0 # recommendation is cheaper → negative %
    assert_in_delta est.savings[:monthly] * 12, est.savings[:yearly], 0.01
  end

  test "baseline already cheapest reports no switch" do
    est = estimate(tier: "any", base: "deepseek-v4-pro")

    assert est.same?
    assert_equal "deepseek-v4-pro", est.baseline.slug
  end

  test "unknown baseline slug falls back to the cheapest row" do
    est = estimate(tier: "any", base: "no-such-model")
    assert_equal est.rows.first.slug, est.baseline.slug
  end

  test "no model fits when the request exceeds every context window" do
    est = estimate(sys: 0, fresh: 5_000_000, out: 0, tier: "any")

    assert_nil est.recommendation
    assert est.rows.none?(&:fits?)
  end

  test "capability floor excludes models below the requested tier" do
    # All fixtures are frontier; a frontier floor keeps them, a higher rank check
    # is exercised via the rank helpers.
    assert_equal 1, CostEstimate.floor_rank("small")
    assert_equal 2, CostEstimate.floor_rank("mid")
    assert_equal 3, CostEstimate.floor_rank("frontier")
    assert_equal 3, CostEstimate.tier_rank("frontier")
    assert CostEstimate.tier_rank("frontier") >= CostEstimate.floor_rank("mid")
  end

  test "retrospective dates ascend and the cheap workload gets cheaper over time" do
    series = estimate(sys: 0, fresh: 100_000, out: 0, req: 1000, tier: "any").retrospective

    assert_operator series.size, :>=, 2
    dates = series.map { |p| p[:date] }
    assert_equal dates.sort, dates
    # The DeepSeek price cut means the cheapest fitting model costs less today
    # than at the earliest dated point.
    assert_operator series.last[:monthly], :<, series.first[:monthly]
  end

  test "strategy hints are contextual and capped at three" do
    hints = estimate(sys: 4000, cache: 10, tier: "any").strategy_hints

    assert_operator hints.size, :<=, 3
    assert hints.any? { |h| h.title == "Cache the context" }
    assert hints.all? { |h| h.is_a?(CostEstimate::Hint) }
  end

  test "profile_from clamps out-of-range values and defaults blanks" do
    p = CostEstimate.profile_from(sys: -50, cache: 250, req: "", tier: "bogus", out: "900")

    assert_equal 0, p.sys                       # clamped up to the floor
    assert_equal 95, p.cache                     # clamped to the ceiling
    assert_equal CostEstimate::DEFAULT[:req], p.req # blank → default
    assert_equal CostEstimate::DEFAULT[:tier], p.tier # invalid → default
    assert_equal 900, p.out
  end

  test "to_query round-trips a profile through params" do
    p = CostEstimate.profile_from(sys: 1200, fresh: 300, out: 600, req: 200_000, cache: 40, tier: "mid", base: "x")
    again = CostEstimate.profile_from(p.to_query)

    assert_equal p, again
  end

  test "heuristic fill parses volume and infers a workload shape" do
    classify = CostEstimate.heuristic_fill("Classify 1M tickets per month by topic")
    assert_equal 1_000_000, classify[:req]
    assert_equal "small", classify[:tier]

    chat = CostEstimate.heuristic_fill("Support bot over our docs, 5k chats/day, 3 turns each")
    assert_equal 150_000, chat[:req] # 5k × 30 days
    assert_operator chat[:sys], :>, 1000 # RAG over docs → large reused context
  end
end
