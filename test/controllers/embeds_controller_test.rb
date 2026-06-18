require "test_helper"

class EmbedsControllerTest < ActionDispatch::IntegrationTest
  test "renders the embed frame priced for the model as baseline" do
    get model_estimate_url("claude-opus-4-8", in_pos: 50, out_pos: 40, req: 100_000)
    assert_response :success
    assert_select "turbo-frame#estimate_embed_claude-opus-4-8 .emb-out"
    assert_select ".emb-total"
    assert_select ".emb-cta[href*='/cost']" # deep-links into the full estimator
  end

  test "surfaces a cheaper equivalent when one exists" do
    # Opus is pricey; the catalog has far cheaper fitting models, so the embed
    # should point at a cheapest-equivalent rather than declaring Opus cheapest.
    get model_estimate_url("claude-opus-4-8", in_pos: 60, out_pos: 50, req: 500_000)
    assert_response :success
    assert_select ".emb-cheapest.on"
  end

  test "404s for a model not in the catalog" do
    get model_estimate_url("claude-no-price")
    assert_response :not_found
  end

  test "the model page mounts the embed for a listed model" do
    get model_url("claude-opus-4-8")
    assert_response :success
    assert_select "section.embed-wrap"
    assert_select "turbo-frame#estimate_embed_claude-opus-4-8[src*='/estimate']"
    assert_select "turbo-frame#probe_alert_model_claude-opus-4-8"
  end
end
