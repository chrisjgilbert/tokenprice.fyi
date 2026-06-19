require "test_helper"

class Admin::SignalSignupsControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login when not signed in" do
    get admin_signal_signups_path
    assert_redirected_to admin_login_path
  end

  test "index shows counts and recent signups when signed in" do
    sign_in_admin
    SignalSignup.create!(kind: "measure_interest", email: "a@example.com")
    SignalSignup.create!(kind: "measure_interest", email: "b@example.com")
    SignalSignup.create!(kind: "price_alert", email: "c@example.com", payload: "gpt-4o")

    get admin_signal_signups_path
    assert_response :success
    assert_match "a@example.com", response.body
    assert_match "c@example.com", response.body
    # Both summary counts render.
    assert_match ">2</div>", response.body
    assert_match ">1</div>", response.body
  end

  test "empty state when there are no signups" do
    sign_in_admin
    get admin_signal_signups_path
    assert_response :success
    assert_match "No signups yet.", response.body
  end

  test "CSV export returns text/csv with the rows" do
    sign_in_admin
    SignalSignup.create!(kind: "measure_interest", email: "a@example.com")
    SignalSignup.create!(kind: "price_alert", email: "c@example.com", payload: "gpt-4o")

    get export_admin_signal_signups_path(format: :csv)
    assert_response :success
    assert_match "text/csv", response.media_type
    assert_match "attachment", response.headers["Content-Disposition"]
    assert_match "kind,email,payload,created_at", response.body
    assert_match "measure_interest,a@example.com", response.body
    assert_match "price_alert,c@example.com,gpt-4o", response.body
  end

  test "CSV export redirects to login when not signed in" do
    get export_admin_signal_signups_path(format: :csv)
    assert_redirected_to admin_login_path
  end

  test "CSV export neutralizes spreadsheet formula injection" do
    sign_in_admin
    # email passes the loose format check but starts with a formula trigger;
    # payload is unvalidated and attacker-controlled.
    SignalSignup.create!(kind: "price_alert", email: "+cmd@evil.com", payload: "=HYPERLINK(1)")

    get export_admin_signal_signups_path(format: :csv)
    assert_response :success
    assert_match "'+cmd@evil.com", response.body    # leading + quoted
    assert_match "'=HYPERLINK(1)", response.body     # leading = quoted
    refute_match(/,=HYPERLINK\(1\)/, response.body)  # never written raw
  end
end
