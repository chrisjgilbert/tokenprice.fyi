require "test_helper"

class Admin::ModelCandidatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_admin
    @pending = ModelCandidate.create!(
      name: "Muse Image", provider_name: "Meta", slug: "muse-image", category_slug: "image",
      pricing: { "pricing_model" => "per_image", "price_summary" => "$0.03 / image" },
      source_url: "https://ai.meta.com/blog/muse-image", confidence: "M", status: "pending"
    )
  end

  test "requires admin auth" do
    delete admin_logout_path
    get admin_model_candidates_path
    assert_redirected_to admin_login_path
  end

  test "GET index lists the pending candidate with its price and source" do
    get admin_model_candidates_path
    assert_response :success
    assert_match "Muse Image", response.body
    assert_match "$0.03 / image", response.body
    assert_match "ai.meta.com/blog/muse-image", response.body
  end

  test "PATCH accept creates the manual AiModel row and marks the candidate accepted" do
    model = nil
    assert_difference "AiModel.count", 1 do
      patch accept_admin_model_candidate_path(@pending)
    end
    assert_redirected_to admin_model_candidates_path
    assert_equal "accepted", @pending.reload.status
    model = AiModel.find_by(slug: "muse-image")
    assert_equal :image_generation, model.modality_class
    assert_equal AiModel::MANUAL_SOURCE, model.source
    assert model.native_priced?
  end

  test "PATCH dismiss marks the candidate dismissed and creates no model" do
    assert_no_difference "AiModel.count" do
      patch dismiss_admin_model_candidate_path(@pending)
    end
    assert_redirected_to admin_model_candidates_path
    assert_equal "dismissed", @pending.reload.status
  end

  test "accepting is idempotent and doesn't error on a re-accept" do
    patch accept_admin_model_candidate_path(@pending)
    assert_no_difference "AiModel.count" do
      patch accept_admin_model_candidate_path(@pending)
    end
    assert_redirected_to admin_model_candidates_path
  end
end
