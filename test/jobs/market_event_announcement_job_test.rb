require "test_helper"

class MarketEventAnnouncementJobTest < ActiveSupport::TestCase
  # Stub the social clients so the job exercises the job → operation → stamp
  # wiring without reaching a real social API. Relying on "no credentials in
  # test" is not enough: with the master key present the credentials decrypt and
  # the clients would post the fixture text to the live accounts.
  def stub_post(client)
    original = client.singleton_class.instance_method(:post)
    client.define_singleton_method(:post) { |text:| nil }
    yield
  ensure
    client.singleton_class.define_method(:post, original)
  end

  test "performing the job runs the announcement and stamps announced_at" do
    event = MarketEvent.create!(
      title: "Provider repriced a model", note: "Cheaper now.",
      event_date: Date.new(2026, 6, 30), kind: "market", status: "published"
    )

    assert_nil event.announced_at
    stub_post(BlueskyClient) do
      stub_post(MastodonClient) do
        MarketEventAnnouncementJob.perform_now(event)
      end
    end
    assert_not_nil event.reload.announced_at
  end
end
