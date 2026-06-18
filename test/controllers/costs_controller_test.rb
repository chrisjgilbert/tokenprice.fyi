require "test_helper"

class CostsControllerTest < ActionDispatch::IntegrationTest
  test "renders the estimator with a default workload" do
    get cost_url
    assert_response :success
    assert_select "h1", /Price your workload across every model/
    assert_select "#cost_result .co-hero"      # a result is shown immediately
    assert_select ".co-board .co-brow"         # every model priced
    assert_select ".co-input form"             # the editable profile form
  end

  test "reflects workload params and round-trips the permalink" do
    get cost_url(sys: 1000, fresh: 500, out: 200, req: 100_000, cache: 40, tier: "mid", base: "deepseek-v4-pro")
    assert_response :success
    assert_select "input#sys[value='1000']"
    assert_select "input#req[value='100000']"
    # baseline preselected
    assert_select "select#base option[selected][value='deepseek-v4-pro']"
  end

  test "a Turbo-Frame request returns only the result frame" do
    get cost_url(sys: 0, fresh: 1_000_000, out: 0, req: 1, tier: "any"),
        headers: { "Turbo-Frame" => "cost_result" }
    assert_response :success
    assert_select "turbo-frame#cost_result", false # frame-only render: no nested frame tag, just its contents
    assert_select "h1", false                        # no page chrome
    assert_select ".co-board .co-brow"
  end

  test "the describe on-ramp heuristic-fills and redirects to a clean permalink" do
    get cost_url(describe: "Classify 1M tickets per month by topic")
    assert_response :redirect
    assert_match %r{/cost\?}, @response.location
    follow_redirect!
    assert_select "input#req[value='1000000']"
  end

  test "shows the no-model-fits state when the request exceeds every context window" do
    get cost_url(fresh: 5_000_000, tier: "any")
    assert_response :success
    assert_select ".co-hero.is-nofit"
    assert_select ".co-reco-note", /No model in this capability tier/
  end

  test "exposes both demand probes on the estimator" do
    get cost_url
    assert_select "turbo-frame#probe_measure_cost .probe-measure"
    assert_select "turbo-frame#probe_alert_cost .probe-alert"
  end
end
