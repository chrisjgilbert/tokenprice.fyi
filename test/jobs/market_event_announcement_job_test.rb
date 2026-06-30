require "test_helper"

class MarketEventAnnouncementJobTest < ActiveSupport::TestCase
  # No social credentials in test, so the clients no-op — this exercises the
  # job → operation → stamp wiring without any external HTTP.
  test "performing the job runs the announcement and stamps announced_at" do
    event = MarketEvent.create!(
      title: "Provider repriced a model", note: "Cheaper now.",
      event_date: Date.new(2026, 6, 30), kind: "market", status: "published"
    )

    assert_nil event.announced_at
    MarketEventAnnouncementJob.perform_now(event)
    assert_not_nil event.reload.announced_at
  end
end
