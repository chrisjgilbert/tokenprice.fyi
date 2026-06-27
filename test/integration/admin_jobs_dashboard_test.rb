require "test_helper"

class AdminJobsDashboardTest < ActionDispatch::IntegrationTest
  test "the jobs dashboard redirects to login when signed out" do
    get admin_mission_control_jobs_path
    # Literal path, not admin_login_path: after a request into the mounted
    # engine, the helper picks up the engine's script_name (/admin/jobs) and
    # would resolve to /admin/jobs/admin/login.
    assert_redirected_to "/admin/login"
  end

  test "the jobs dashboard renders for a signed-in admin" do
    sign_in_admin
    get admin_mission_control_jobs_path
    # The engine root redirects to a trailing slash before rendering; follow it
    # so a 500 can't masquerade as a pass the way a bare not-login-redirect would.
    follow_redirect! while response.redirect?
    assert_response :success
  end
end
