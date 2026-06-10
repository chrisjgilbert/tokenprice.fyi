require "test_helper"

class Admin::ModelsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_admin }

  test "index lists models" do
    get admin_models_path
    assert_response :success
    assert_select "th[scope=row]", /Claude Opus 4.8/
  end

  test "creates a model with an auto-generated slug" do
    assert_difference "AiModel.count", 1 do
      post admin_models_path, params: { ai_model: {
        provider_id: providers(:anthropic).id, name: "Claude Test 9", tier: "mid", status: "active"
      } }
    end
    assert_redirected_to admin_models_path
    assert AiModel.exists?(slug: "claude-test-9")
  end

  test "rejects an invalid model" do
    assert_no_difference "AiModel.count" do
      post admin_models_path, params: { ai_model: { name: "", tier: "bogus" } }
    end
    assert_response :unprocessable_entity
  end

  test "updates a model" do
    patch admin_model_path(ai_models(:opus)), params: { ai_model: { status: "legacy" } }
    assert_redirected_to admin_models_path
    assert_equal "legacy", ai_models(:opus).reload.status
  end

  test "deletes a model" do
    assert_difference "AiModel.count", -1 do
      delete admin_model_path(ai_models(:opus))
    end
    assert_redirected_to admin_models_path
  end
end
