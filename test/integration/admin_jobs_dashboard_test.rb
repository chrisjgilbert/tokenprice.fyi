require "test_helper"

class AdminJobsDashboardTest < ActionDispatch::IntegrationTest
  test "the jobs dashboard redirects to login when signed out" do
    get "/admin/jobs"
    assert_equal "/admin/login", URI(response.location.to_s).path
  end

  test "the jobs dashboard renders for a signed-in admin" do
    sign_in_admin
    get "/admin/jobs"
    # The engine root redirects to a trailing slash before rendering; follow it
    # so a 500 can't masquerade as a pass the way a bare not-login-redirect would.
    follow_redirect! while response.redirect?
    assert_response :success
  end
end
