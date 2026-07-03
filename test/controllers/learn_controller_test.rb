require "test_helper"

class LearnControllerTest < ActionDispatch::IntegrationTest
  test "the learn index is a lean directory of the four real explainers" do
    get learn_url
    assert_response :success
    # Links to each of the four built explainers; anatomy was removed.
    assert_select "a[href=?]", how_pricing_works_path
    assert_select "a[href=?]", learn_reasoning_path
    assert_select "a[href=?]", learn_feature_costs_path
    assert_select "a[href=?]", learn_cost_cutting_path
    assert_no_match(%r{href="/learn/anatomy"}, response.body)
    # The standalone /cost estimator was removed; no dead reference remains.
    assert_select ".led-cta", false
    assert_no_match(%r{href="/cost(\?[^"]*)?"}, response.body)
  end

  test "the learn index renders the locked intro line" do
    get learn_url
    assert_response :success
    assert_select "h1", /Understand what you're paying for/
    assert_match(
      "What an LLM feature actually costs, and why: the chain of calls it runs, " \
      "how the bill reads, what reasoning tokens add, where the tokens go, and which levers cut it.",
      response.body
    )
  end

  test "the learn index shows roadmap explainers as muted, non-link Next up cards" do
    get learn_url
    assert_response :success
    # The remaining roadmap topics render as coming-soon cards so the series shows
    # its breadth; content lands later. (Reasoning graduated to a built explainer.)
    assert_select "div.led-soon", 3
    assert_select "a.led-soon", false              # not links — nothing to read yet
    assert_select ".led-soon-tag", { minimum: 1, text: /Next up/i }
    [ "Prompt caching", "Batch processing", "What an AI agent actually costs" ].each do |topic|
      assert_includes response.body, topic
    end
  end

  test "the feature-costs explainer renders and has no dead estimator CTA" do
    get learn_feature_costs_url
    assert_response :success
    assert_select "h1", /What drives the cost of common features/
    # The /cost estimator was removed; its CTA is gone, the ghost cross-link stays.
    assert_no_dead_cost_cta
    assert_select ".hp-cta a"
  end

  test "the feature-costs intro is a cost-breakdown angle, not best-model" do
    get learn_feature_costs_url
    assert_response :success
    # This page holds the informational "what X costs" intent, not "which model to pick".
    assert_match(/what (each|a) feature costs/i, response.body)
    assert_select "h1", /What (LLM features cost|drives the cost)/
  end

  # The io_ratio widget was removed from the explainers as awkward, except on the
  # reasoning page, where the output:input spread IS the reasoning tax. Guard both
  # halves: present on reasoning, absent everywhere else.
  test "the io_ratio widget renders only on the reasoning explainer" do
    get learn_reasoning_url
    assert_response :success
    assert_select ".lw", { minimum: 1 }, "expected the live io_ratio widget on the reasoning explainer"
    assert_match(/prices today/, response.body)

    [ learn_feature_costs_url, learn_cost_cutting_url, how_pricing_works_url ].each do |url|
      get url
      assert_response :success
      assert_select ".lw", false, "the io_ratio widget should be gone from #{url}"
    end
  end

  test "the cost-cutting explainer renders and has no dead estimator CTA" do
    get learn_cost_cutting_url
    assert_response :success
    assert_select "h1", /Cost-cutting strategies/
    assert_no_dead_cost_cta
    assert_select ".hp-cta a"
  end

  test "how-pricing-works renders and has no dead estimator CTA" do
    get how_pricing_works_url
    assert_response :success
    assert_no_dead_cost_cta
    assert_select ".hp-cta a"
  end

  test "the reasoning explainer renders with live data and the no-fixed-multiplier stance" do
    get learn_reasoning_url
    assert_response :success
    assert_select "h1", /Reasoning/
    # Live data (AUDIT #3): the io_ratio widget plus a live frontier worked example.
    assert_select ".lw"
    assert_match(/prices today/, response.body)
    fm = AiModel.listed.where(tier: "frontier").select(&:current_input).min_by(&:current_input)
    assert fm, "expected a priced frontier model in fixtures"
    assert_match(/#{Regexp.escape(fm.name)}/, response.body)
    # The core stance: effort is a volume dial, and there's no fixed per-model multiplier.
    assert_match(/volume dial, not a price dial/i, response.body)
    assert_match(/no fixed multiplier/i, response.body)
    # Cross-links to its conceptual neighbours.
    assert_select "article.hp a[href=?]", how_pricing_works_path
    assert_select "article.hp a[href=?]", learn_cost_cutting_path
    assert_no_dead_cost_cta
  end

  private

  # No link points at the removed /cost destination (exact path or with a query
  # string) — anchored so the live /learn/cost-cutting cross-link doesn't match.
  def assert_no_dead_cost_cta
    assert_no_match(%r{href="/cost(\?[^"]*)?"}, response.body)
  end
end
