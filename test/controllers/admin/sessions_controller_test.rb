require "test_helper"

class Admin::SessionsControllerTest < ActionDispatch::IntegrationTest
  test "login page renders" do
    get admin_login_path
    assert_response :success
    assert_select "input[type=password]"
  end

  test "admin pages redirect to login when signed out" do
    get admin_models_path
    assert_redirected_to admin_login_path
  end

  test "correct password signs in" do
    sign_in_admin
    assert_redirected_to admin_root_path
    get admin_models_path
    assert_response :success
  end

  test "wrong password is rejected" do
    stub_admin_digest!
    post admin_login_path, params: { password: "nope" }
    assert_response :unprocessable_entity
    get admin_models_path
    assert_redirected_to admin_login_path
  end

  test "missing digest never authenticates" do
    stub_admin_digest!(nil)
    post admin_login_path, params: { password: "anything" }
    assert_response :unprocessable_entity
  end

  test "logout clears the session" do
    sign_in_admin
    delete admin_logout_path
    assert_redirected_to admin_login_path
    get admin_models_path
    assert_redirected_to admin_login_path
  end
end
