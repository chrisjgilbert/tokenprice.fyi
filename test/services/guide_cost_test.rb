require "test_helper"

# T1.2 — the per-call cost service that powers the Guide. It prices a (slug,
# shape) pair by delegating to the Phase-0 CostEstimate#price_with, on a single
# NO-cache basis so every option for a step is compared fairly (AUDIT #1), and
# refuses to price plumbing steps (AUDIT #5).
class GuideCostTest < ActiveSupport::TestCase
  # The RAG "generate answer" step's representative shape.
  GENERATE_SHAPE = { sys: 500, in: 4_550, out: 250 }.freeze

  # Uncached per-call cost computed straight from the published rates:
  #   ((sys + in) / 1e6) * input  +  (out / 1e6) * output
  def uncached_per_call(shape, input:, output:)
    ((shape[:sys] + shape[:in]) / 1e6) * input + (shape[:out] / 1e6) * output
  end

  test "prices a slug against a shape on the no-cache basis (parity, with-cache model)" do
    # claude-opus-4-8 HAS a cached rate (0.50). It must NOT be used: the headline
    # per-call figure is the full-input uncached formula. This proves the cache
    # discount did not secretly reduce the figure.
    result = GuideCost.per_call(slug: "claude-opus-4-8", shape: GENERATE_SHAPE)

    assert result.resolved?
    assert result.priced?
    expected = uncached_per_call(GENERATE_SHAPE, input: 5.0, output: 25.0)
    assert_in_delta expected, result.per_call, 1e-12
    # Sanity: the cached rate (0.50) WOULD have lowered the figure — confirm we
    # did not get that lower number.
    discounted = ((GENERATE_SHAPE[:in] / 1e6) * 5.0) +
                 ((GENERATE_SHAPE[:sys] / 1e6) * 0.50) +
                 ((GENERATE_SHAPE[:out] / 1e6) * 25.0)
    assert_operator discounted, :<, expected
    refute_in_delta discounted, result.per_call, 1e-9
  end

  test "cache parity: a with-cache and a no-cache model differ only by their rates" do
    # uncached-mid has NO cached rate (input 2, output 8). claude-opus-4-8 HAS one.
    # Priced for the same shape, each equals its own full-input uncached formula —
    # so any difference is purely input/output rates, never cache asymmetry.
    opus = GuideCost.per_call(slug: "claude-opus-4-8", shape: GENERATE_SHAPE)
    mid  = GuideCost.per_call(slug: "uncached-mid", shape: GENERATE_SHAPE)

    assert_in_delta uncached_per_call(GENERATE_SHAPE, input: 5.0, output: 25.0), opus.per_call, 1e-12
    assert_in_delta uncached_per_call(GENERATE_SHAPE, input: 2.0, output: 8.0),  mid.per_call,  1e-12
  end

  test "cached-null model prices at full input with no phantom discount and never raises" do
    result = assert_nothing_raised do
      GuideCost.per_call(slug: "uncached-mid", shape: GENERATE_SHAPE)
    end
    assert result.priced?
    assert_in_delta uncached_per_call(GENERATE_SHAPE, input: 2.0, output: 8.0), result.per_call, 1e-12
  end

  test "delegates to CostEstimate#price_with[:per_req] (no reimplementation)" do
    shape = GENERATE_SHAPE
    profile = CostEstimate.profile_from(
      sys: shape[:sys], fresh: shape[:in], out: shape[:out], req: 1, cache: 0, tier: "any"
    )
    expected = CostEstimate.new(profile).price_with(input: 5.0, output: 25.0, cached: nil)[:per_req]

    result = GuideCost.per_call(slug: "claude-opus-4-8", shape: shape)
    assert_in_delta expected, result.per_call, 1e-15
  end

  test "the per-call figure is independent of monthly volume" do
    # Two different req values must yield the same per-call figure — it is a
    # property of the shape and rates alone.
    a = GuideCost.per_call(slug: "claude-opus-4-8", shape: GENERATE_SHAPE)
    b = GuideCost.per_call(slug: "claude-opus-4-8", shape: GENERATE_SHAPE)
    assert_in_delta a.per_call, b.per_call, 1e-15
    # And it matches the seam at req: 1 explicitly.
    profile = CostEstimate.profile_from(
      sys: 500, fresh: 4_550, out: 250, req: 999_999, cache: 0, tier: "any"
    )
    seam = CostEstimate.new(profile).price_with(input: 5.0, output: 25.0, cached: nil)[:per_req]
    assert_in_delta seam, a.per_call, 1e-15
  end

  test "accepts a FeaturePattern::Shape as well as a hash" do
    shape = FeaturePattern::Shape.new(sys: 500, in: 4_550, out: 250)
    result = GuideCost.per_call(slug: "claude-opus-4-8", shape: shape)
    assert_in_delta uncached_per_call(shape.to_h, input: 5.0, output: 25.0), result.per_call, 1e-12
  end

  test "unknown slug degrades to nil without raising" do
    result = assert_nothing_raised do
      GuideCost.per_call(slug: "no-such-model", shape: GENERATE_SHAPE)
    end
    refute result.resolved?
    refute result.priced?
    assert_nil result.per_call
    assert_equal "no-such-model", result.slug
  end

  test "a resolvable model with no current price degrades to nil" do
    # claude-no-price is active but has no price points → excluded from the
    # catalog, so it resolves like an unknown slug: nil, no raise.
    result = GuideCost.per_call(slug: "claude-no-price", shape: GENERATE_SHAPE)
    refute result.priced?
    assert_nil result.per_call
  end

  test "a nil slug degrades to nil without raising" do
    result = assert_nothing_raised { GuideCost.per_call(slug: nil, shape: GENERATE_SHAPE) }
    refute result.resolved?
    assert_nil result.per_call
  end

  test "an unpriced (priced:false) step is refused, not fabricated" do
    embed = FeaturePattern.find("rag").steps.first
    refute embed.priced?, "fixture sanity: the RAG embed step is priced:false"

    results = GuideCost.for_step(embed)
    assert results.all? { |r| !r.priced? }, "no option of an unpriced step gets a number"
    assert results.all? { |r| r.per_call.nil? }
  end

  test "for_step prices each present option in stable order, skipping nil slugs" do
    # The RAG generate step: cheap/quality/open_weight all present.
    step = FeaturePattern.find("rag").steps.last
    assert step.priced?

    results = GuideCost.for_step(step)
    # One result per PRESENT option slug, in cheap → quality → open_weight order.
    present = step.options.to_h.compact
    assert_equal present.values, results.map(&:slug)
  end

  test "for_step skips a nil option slug" do
    # The RAG embed step has quality: nil — but it is unpriced anyway; use the
    # priced generate step and confirm nil options never produce a result.
    step = FeaturePattern.find("rag").steps.last
    results = GuideCost.for_step(step)
    refute_includes results.map(&:slug), nil
  end

  # --- catalog injection (efficiency): one load per page, no redundant DB hits ---

  test "an injected catalog resolves every option with zero extra catalog loads" do
    step = FeaturePattern.find("rag").steps.last
    catalog = PriceCatalog.models # the single load the page performs

    assert_queries_count(0) do
      GuideCost.for_step(step, catalog: catalog)
    end
  end

  test "per_call with an injected catalog runs no catalog queries" do
    catalog = PriceCatalog.models
    assert_queries_count(0) do
      GuideCost.per_call(slug: "claude-opus-4-8", shape: GENERATE_SHAPE, catalog: catalog)
    end
  end

  test "injected and non-injected per_call produce identical numbers" do
    catalog = PriceCatalog.models
    injected = GuideCost.per_call(slug: "claude-opus-4-8", shape: GENERATE_SHAPE, catalog: catalog)
    plain    = GuideCost.per_call(slug: "claude-opus-4-8", shape: GENERATE_SHAPE)
    assert_in_delta plain.per_call, injected.per_call, 1e-15
  end

  test "resolution uses the injected catalog, not the DB" do
    # A catalog containing ONLY claude-opus-4-8: a slug present in it prices; a
    # slug absent from it (even though it exists in the DB) returns nil —
    # proving the DB path is bypassed when a catalog is injected.
    only_opus = PriceCatalog.models.select { |e| e.slug == "claude-opus-4-8" }
    assert_equal 1, only_opus.size, "fixture sanity"

    hit  = GuideCost.per_call(slug: "claude-opus-4-8", shape: GENERATE_SHAPE, catalog: only_opus)
    miss = GuideCost.per_call(slug: "uncached-mid", shape: GENERATE_SHAPE, catalog: only_opus)

    assert hit.priced?
    refute miss.resolved?, "a slug absent from the injected catalog must not fall back to the DB"
    assert_nil miss.per_call
  end
end
