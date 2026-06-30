require "test_helper"

class MarketEvent::AnnouncementTest < ActiveSupport::TestCase
  # minitest/mock's #stub is not loaded in this suite (see slack_notifier_test.rb).
  # Intercept the social clients by defining a singleton .post that captures its
  # text (or raises), then remove it in an ensure to restore the real method.
  def stub_post(client, capture: nil, raise_with: nil)
    client.define_singleton_method(:post) do |text:|
      capture << text if capture
      raise raise_with if raise_with

      nil
    end
    yield
  ensure
    client.singleton_class.send(:remove_method, :post)
  end

  def published_event
    MarketEvent.create!(
      title: "Anthropic cuts Claude Sonnet output pricing",
      note: "Output drops from $15 to $10 per 1M tokens, effective today.",
      event_date: Date.new(2026, 6, 30), kind: "market", status: "published"
    )
  end

  test "draft event posts nothing and leaves announced_at nil" do
    event = MarketEvent.create!(
      title: "Draft", note: "Pending.", event_date: Date.new(2026, 6, 30),
      kind: "market", status: "draft"
    )
    posts = []
    stub_post(BlueskyClient, capture: posts) do
      stub_post(MastodonClient, capture: posts) do
        event.announce
      end
    end

    assert_empty posts
    assert_nil event.reload.announced_at
  end

  test "already-announced event is a no-op and does not call the clients" do
    event = published_event
    event.update_column(:announced_at, Time.current)
    stamp = event.reload.announced_at

    posts = []
    stub_post(BlueskyClient, capture: posts) do
      stub_post(MastodonClient, capture: posts) do
        event.announce
      end
    end

    assert_empty posts
    assert_equal stamp.to_i, event.reload.announced_at.to_i
  end

  test "published, unannounced event posts to both platforms and stamps announced_at" do
    event = published_event
    posts = []
    stub_post(BlueskyClient, capture: posts) do
      stub_post(MastodonClient, capture: posts) do
        event.announce
      end
    end

    assert_equal 2, posts.size
    assert_equal posts[0], posts[1]
    assert_not_nil event.reload.announced_at
  end

  test "a per-platform failure is non-fatal" do
    event = published_event
    mastodon_posts = []

    assert_nothing_raised do
      stub_post(BlueskyClient, raise_with: RuntimeError.new("bsky down")) do
        stub_post(MastodonClient, capture: mastodon_posts) do
          event.announce
        end
      end
    end

    assert_equal 1, mastodon_posts.size, "Mastodon should still be posted when BlueSky fails"
    assert_not_nil event.reload.announced_at, "announced_at is still stamped after a partial failure"
  end

  test "post text contains the title and events link and is within the character limit" do
    event = published_event
    posts = []
    stub_post(BlueskyClient, capture: posts) do
      stub_post(MastodonClient, capture: posts) do
        event.announce
      end
    end

    text = posts.first
    assert_includes text, event.title
    assert_includes text, "https://tokenprice.fyi/events"
    assert_operator text.length, :<=, 300
  end

  test "an overlong note is truncated but the link is preserved" do
    event = MarketEvent.create!(
      title: "Big pricing shift", note: "x" * 500,
      event_date: Date.new(2026, 6, 30), kind: "market", status: "published"
    )
    posts = []
    stub_post(BlueskyClient, capture: posts) do
      stub_post(MastodonClient, capture: posts) do
        event.announce
      end
    end

    text = posts.first
    assert_operator text.length, :<=, 300
    assert text.end_with?("https://tokenprice.fyi/events")
    assert_includes text, "…"
  end
end
