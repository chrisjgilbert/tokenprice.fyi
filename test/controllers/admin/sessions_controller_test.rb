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
    # Anchor every step to a fixed base so there's no wall-clock drift between
    # travels (which would cross the cap boundary early under parallel load).
    base = Time.zone.local(2026, 1, 1, 12, 0, 0)
    travel_to(base) { sign_in_admin }

    # A request every hour stays inside the idle window, right up to the cap.
    (1..11).each do |hour|
      travel_to(base + hour.hours) { get admin_models_path }
      assert_response :success, "expected to remain signed in at hour #{hour}"
    end

    # Just past the absolute cap (idle gap is only ~1h, so this proves the cap).
    travel_to(base + Admin::BaseController::ABSOLUTE_TIMEOUT + 1.minute) do
      get admin_models_path
      assert_redirected_to admin_login_path
    end
  end
end
