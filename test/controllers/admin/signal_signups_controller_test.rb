require "test_helper"
require "csv"

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

  test "CSV guard isn't bypassed by leading whitespace or a newline in payload" do
    sign_in_admin
    SignalSignup.create!(kind: "price_alert", email: "a@example.com", payload: " =HYPERLINK(0,0)")
    SignalSignup.create!(kind: "price_alert", email: "b@example.com", payload: "\n=cmd")

    get export_admin_signal_signups_path(format: :csv)
    assert_response :success

    # Parse the CSV and assert no cell would evaluate as a formula: every
    # dangerous cell must be text (quote-prefixed), so after stripping leading
    # whitespace no cell starts with a formula trigger.
    rows = CSV.parse(response.body, headers: true)
    rows.each do |row|
      row.fields.each do |cell|
        refute cell.to_s.lstrip.match?(/\A[=+\-@]/),
               "cell #{cell.inspect} would be evaluated as a formula"
      end
    end
  end
end
