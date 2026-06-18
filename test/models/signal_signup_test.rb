require "test_helper"

class SignalSignupTest < ActiveSupport::TestCase
  test "stores a measure-interest signup" do
    s = SignalSignup.create!(kind: "measure_interest", email: "dev@example.com", payload: "w=abc")

    assert s.persisted?
    assert_equal "measure_interest", s.kind
    assert_includes SignalSignup.measure_interest, s
  end

  test "stores a price-alert signup" do
    s = SignalSignup.create!(kind: "price_alert", email: "dev@example.com")
    assert_includes SignalSignup.price_alerts, s
  end

  test "rejects an unknown kind" do
    s = SignalSignup.new(kind: "spam", email: "dev@example.com")
    refute s.valid?
    assert_includes s.errors[:kind], "is not included in the list"
  end

  test "requires a plausible email" do
    refute SignalSignup.new(kind: "price_alert", email: "not-an-email").valid?
    refute SignalSignup.new(kind: "price_alert", email: "").valid?
  end

  test "normalizes the email to trimmed lowercase" do
    s = SignalSignup.create!(kind: "price_alert", email: "  Dev@Example.COM ")
    assert_equal "dev@example.com", s.email
  end
end
