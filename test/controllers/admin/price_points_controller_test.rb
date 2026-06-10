require "test_helper"

class Admin::PricePointsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_admin }

  test "requires sign in" do
    delete admin_logout_path
    get new_admin_model_price_point_path(ai_models(:opus))
    assert_redirected_to admin_login_path
  end

  test "adding a newer snapshot becomes the current price" do
    model = ai_models(:opus)
    assert_difference "model.price_points.count", 1 do
      post admin_model_price_points_path(model), params: { price_point: {
        effective_on: Date.new(2026, 6, 1), input_per_mtok: 4, output_per_mtok: 20
      } }
    end
    assert_redirected_to admin_models_path
    assert_equal 4, model.reload.current_input
  end

  test "rejects an invalid price point" do
    model = ai_models(:opus)
    assert_no_difference "PricePoint.count" do
      post admin_model_price_points_path(model), params: { price_point: {
        effective_on: Date.new(2026, 6, 1), input_per_mtok: -1, output_per_mtok: 20
      } }
    end
    assert_response :unprocessable_entity
  end

  test "deletes a snapshot" do
    model = ai_models(:deepseek_v4)
    assert_difference "model.price_points.count", -1 do
      delete admin_model_price_point_path(model, price_points(:deepseek_cut))
    end
  end
end
