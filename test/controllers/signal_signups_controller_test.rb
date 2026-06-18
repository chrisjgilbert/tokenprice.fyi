require "test_helper"

class SignalSignupsControllerTest < ActionDispatch::IntegrationTest
  test "captures a measure-interest opt-in and shows the success state" do
    assert_difference -> { SignalSignup.measure_interest.count }, 1 do
      post signal_signups_path, params: {
        kind: "measure_interest", email: "dev@example.com",
        variant: "measure", frame_id: "probe_measure_est", payload: "w=abc"
      }
    end
    assert_response :success
    assert_select "turbo-frame#probe_measure_est .probe.is-done"
    assert_match "dev@example.com", @response.body
  end

  test "captures a price-alert opt-in" do
    assert_difference -> { SignalSignup.price_alerts.count }, 1 do
      post signal_signups_path, params: {
        kind: "price_alert", email: "dev@example.com",
        variant: "alert", frame_id: "probe_alert_model"
      }
    end
    assert_response :success
    assert_select "turbo-frame#probe_alert_model .probe.is-done"
  end

  test "rejects an invalid email and re-renders the card with an error" do
    assert_no_difference -> { SignalSignup.count } do
      post signal_signups_path, params: {
        kind: "price_alert", email: "nope", variant: "alert", frame_id: "probe_alert_model"
      }
    end
    assert_response :unprocessable_entity
    assert_select "turbo-frame#probe_alert_model .probe-err"
  end
end
