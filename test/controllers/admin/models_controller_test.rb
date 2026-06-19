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

  test "the slug is locked on update" do
    patch admin_model_path(ai_models(:opus)),
          params: { ai_model: { slug: "hijacked-slug", status: "legacy" } }
    assert_redirected_to admin_models_path
    opus = ai_models(:opus).reload
    assert_equal "claude-opus-4-8", opus.slug # unchanged
    assert_equal "legacy", opus.status         # other fields still update
  end

  test "admin can change a model's data source and OpenRouter link" do
    patch admin_model_path(ai_models(:opus)),
          params: { ai_model: { source: "openrouter", openrouter_id: "anthropic/claude-opus-4-8" } }
    assert_redirected_to admin_models_path
    opus = ai_models(:opus).reload
    assert_equal "openrouter", opus.source
    assert_equal "anthropic/claude-opus-4-8", opus.openrouter_id
  end

  test "clearing the OpenRouter id unlinks the model" do
    ai_models(:opus).update_column(:openrouter_id, "anthropic/x")
    patch admin_model_path(ai_models(:opus)), params: { ai_model: { openrouter_id: "" } }
    assert_redirected_to admin_models_path
    assert_nil ai_models(:opus).reload.openrouter_id
  end

  test "rejects an OpenRouter id already linked to another model" do
    ai_models(:deepseek_v4).update_column(:openrouter_id, "deepseek/v4")
    patch admin_model_path(ai_models(:opus)), params: { ai_model: { openrouter_id: "deepseek/v4" } }
    assert_response :unprocessable_entity
    assert_nil ai_models(:opus).reload.openrouter_id
  end
end
