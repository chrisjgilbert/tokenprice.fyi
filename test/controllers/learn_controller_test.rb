require "test_helper"

class LearnControllerTest < ActionDispatch::IntegrationTest
  test "the learn index is a lean directory of the four real explainers" do
    get learn_url
    assert_response :success
    # Links to each of the four built explainers, including the anatomy on-ramp.
    assert_select "a[href=?]", learn_anatomy_path
    assert_select "a[href=?]", how_pricing_works_path
    assert_select "a[href=?]", learn_feature_costs_path
    assert_select "a[href=?]", learn_cost_cutting_path
    # The standalone /cost estimator was removed; no dead reference remains.
    assert_select ".led-cta", false
    assert_no_match(%r{href="/cost(\?[^"]*)?"}, response.body)
  end

  test "the learn index renders the locked four-explainer intro line" do
    get learn_url
    assert_response :success
    assert_select "h1", /Understand what you're paying for/
    assert_match(
      "Four explainers on what an LLM feature costs and why: the call chain a feature runs, " \
      "how an API bill reads, where the tokens go, and which levers cut it.",
      response.body
    )
  end

  test "the learn index drops the vaporware stub concepts and series chrome" do
    get learn_url
    assert_no_match(/Prompt caching/, response.body)
    assert_no_match(/Batch processing/, response.body)
    assert_no_match(/Reasoning/, response.body)
    assert_no_match(/What an AI agent actually costs/, response.body)
    assert_no_match(/Next up/, response.body)
  end

  test "the feature-costs explainer has a live widget and no dead estimator CTA" do
    get learn_feature_costs_url
    assert_response :success
    assert_select "h1", /What drives the cost of common features/
    assert_select ".lw"                                # embedded live-data widget
    # The /cost estimator was removed; its CTA is gone, the ghost cross-link stays.
    assert_no_dead_cost_cta
    assert_select ".hp-cta a"
  end

  test "the cost-cutting explainer renders with a live widget and no dead estimator CTA" do
    get learn_cost_cutting_url
    assert_response :success
    assert_select "h1", /Cost-cutting strategies/
    assert_select ".lw"
    assert_no_dead_cost_cta
    assert_select ".hp-cta a"
  end

  test "how-pricing-works has a live widget and no dead estimator CTA" do
    get how_pricing_works_url
    assert_response :success
    assert_select ".lw"
    assert_no_dead_cost_cta
    assert_select ".hp-cta a"
  end

  test "the anatomy explainer renders with the locked H1 and closing callout" do
    get learn_anatomy_url
    assert_response :success
    assert_select "h1", /What an AI feature is actually made of/
    # The closing callout is locked verbatim — the canonical paired terms.
    assert_match(
      "The cost-driver step and the capable-model step are usually different.",
      response.body
    )
    # No retired euphemisms.
    assert_no_match(/expensive step/, response.body)
    assert_no_match(/smart step/, response.body)
  end

  test "the anatomy explainer carries live data: the io_ratio widget and a frontier example" do
    get learn_anatomy_url
    assert_response :success
    assert_select ".lw"                       # the live io_ratio widget
    assert_match(/prices today/, response.body)
    # A live frontier-model example price (mono): the cheapest frontier model's rate.
    fm = AiModel.listed.where(tier: "frontier").select(&:current_input).min_by(&:current_input)
    if fm
      assert_match(/#{Regexp.escape(fm.name)}/, response.body)
      assert_select "span.num"
    end
  end

  test "the anatomy explainer renders worked call-chains from FeaturePattern, agent loop included" do
    get learn_anatomy_url
    assert_response :success
    # Roles come straight off the FeaturePattern source, not a second copy.
    rag = FeaturePattern.find("rag")
    rag.steps.each { |s| assert_match(/#{Regexp.escape(s.role)}/, response.body) }
    agentic = FeaturePattern.find("agentic")
    agentic.steps.each { |s| assert_match(/#{Regexp.escape(s.role)}/, response.body) }
    # The real agent LOOP must show (the looping subagent step), not a mislabel.
    loop_step = agentic.steps.find(&:loops?)
    assert loop_step, "expected the agentic pattern to have a looping step"
    assert_match(/#{Regexp.escape(loop_step.role)}/, response.body)
    assert_match(/loops|repeats/, response.body)
  end

  test "the anatomy explainer is the on-ramp to feature_costs and the guide, not a replacement" do
    get learn_anatomy_url
    assert_response :success
    assert_select "a[href=?]", learn_feature_costs_path
    assert_select "a[href=?]", guide_path
  end

  private

  # No link points at the removed /cost destination (exact path or with a query
  # string) — anchored so the live /learn/cost-cutting cross-link doesn't match.
  def assert_no_dead_cost_cta
    assert_no_match(%r{href="/cost(\?[^"]*)?"}, response.body)
  end
end
