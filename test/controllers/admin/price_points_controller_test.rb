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
    assert_redirected_to edit_admin_model_path(model)
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

  test "persists the non-text pricing dimensions on create" do
    model = ai_models(:opus)
    post admin_model_price_points_path(model), params: { price_point: {
      effective_on: Date.new(2026, 6, 1), input_per_mtok: 4, output_per_mtok: 20,
      cache_write_per_mtok: 5, audio_input_per_mtok: 40,
      image_input_usd: 0.002, request_usd: 0.01
    } }
    pp = model.price_points.find_by!(effective_on: Date.new(2026, 6, 1))
    assert_equal 5, pp.cache_write_per_mtok
    assert_equal 40, pp.audio_input_per_mtok
    assert_equal 0.002, pp.image_input_usd
    assert_equal 0.01, pp.request_usd
  end

  test "blank non-text pricing dimensions persist as nil" do
    model = ai_models(:opus)
    post admin_model_price_points_path(model), params: { price_point: {
      effective_on: Date.new(2026, 6, 1), input_per_mtok: 4, output_per_mtok: 20,
      cache_write_per_mtok: "", audio_input_per_mtok: "",
      image_input_usd: "", request_usd: ""
    } }
    pp = model.price_points.find_by!(effective_on: Date.new(2026, 6, 1))
    assert_nil pp.cache_write_per_mtok
    assert_nil pp.audio_input_per_mtok
    assert_nil pp.image_input_usd
    assert_nil pp.request_usd
  end

  test "edits the non-text pricing dimensions" do
    pp = price_points(:sonnet_launch)
    model = pp.ai_model
    patch admin_model_price_point_path(model, pp), params: { price_point: {
      cache_write_per_mtok: 7, image_input_usd: 0.004
    } }
    pp.reload
    assert_equal 7, pp.cache_write_per_mtok
    assert_equal 0.004, pp.image_input_usd
  end

  test "the edit form renders inputs for the non-text pricing dimensions" do
    pp = price_points(:sonnet_launch)
    get edit_admin_model_price_point_path(pp.ai_model, pp)
    assert_response :success
    assert_select "input[name='price_point[cache_write_per_mtok]']"
    assert_select "input[name='price_point[audio_input_per_mtok]']"
    assert_select "input[name='price_point[image_input_usd]']"
    assert_select "input[name='price_point[request_usd]']"
  end

  test "the price history shows non-text dimensions when present" do
    pp = price_points(:sonnet_launch)
    get edit_admin_model_path(pp.ai_model)
    assert_response :success
    assert_match "0.002", @response.body
  end

  test "persists a native price with blank text rates for a directory model" do
    model = ai_models(:image_gen)
    assert_difference "model.price_points.count", 1 do
      post admin_model_price_points_path(model), params: { price_point: {
        effective_on: Date.new(2026, 6, 1), input_per_mtok: "", output_per_mtok: "",
        native_price_usd: 0.05, source: "example.com/pricing"
      } }
    end
    assert_redirected_to edit_admin_model_path(model)
    pp = model.price_points.find_by!(effective_on: Date.new(2026, 6, 1))
    assert_equal 0.05, pp.native_price_usd
    assert_nil pp.input_per_mtok
    assert_nil pp.output_per_mtok
  end

  test "edits the native price and it round-trips on the form" do
    pp = price_points(:priced_image_gen_native)
    model = pp.ai_model
    patch admin_model_price_point_path(model, pp), params: { price_point: {
      native_price_usd: 0.08
    } }
    assert_equal 0.08, pp.reload.native_price_usd

    get edit_admin_model_price_point_path(model, pp)
    assert_response :success
    assert_select "input[name='price_point[native_price_usd]'][value=?]", "0.08"
  end

  test "a blank native price persists as nil" do
    pp = price_points(:sonnet_launch)
    model = pp.ai_model
    patch admin_model_price_point_path(model, pp), params: { price_point: {
      native_price_usd: ""
    } }
    assert_nil pp.reload.native_price_usd
  end

  test "the edit form renders a native price input" do
    pp = price_points(:priced_image_gen_native)
    get edit_admin_model_price_point_path(pp.ai_model, pp)
    assert_response :success
    assert_select "input[name='price_point[native_price_usd]']"
  end

  test "the price history shows the native price for a directory model" do
    pp = price_points(:priced_image_gen_native)
    get edit_admin_model_path(pp.ai_model)
    assert_response :success
    assert_match "0.04", @response.body
    assert_match "image", @response.body
  end
end
