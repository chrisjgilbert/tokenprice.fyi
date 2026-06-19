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

  test "session expires after the idle timeout" do
    sign_in_admin
    get admin_models_path
    assert_response :success

    travel(Admin::BaseController::IDLE_TIMEOUT + 1.minute) do
      get admin_models_path
      assert_redirected_to admin_login_path
      follow_redirect!
      assert_select ".text-rose-800", /session expired/i
    end
  end

  test "activity within the idle window keeps the session alive" do
    sign_in_admin
    travel(Admin::BaseController::IDLE_TIMEOUT - 5.minutes) do
      get admin_models_path
      assert_response :success
    end
  end

  test "session expires at the absolute cap even when kept active" do
    sign_in_admin
    # A request every hour stays inside the idle window, but the absolute cap
    # still forces re-authentication.
    (1..12).each do |hour|
      travel(hour.hours) { get admin_models_path }
      assert_response :success, "expected to remain signed in at hour #{hour}"
    end
    travel(13.hours) { get admin_models_path }
    assert_redirected_to admin_login_path
  end
end
