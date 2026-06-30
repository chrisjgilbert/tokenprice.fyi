require "test_helper"

class SocialBroadcastTest < ActiveSupport::TestCase
  # The clients are real `def self.post`; capture the originals and restore them
  # (removing would delete the real method and leak across tests).
  def stub_clients(bluesky_raises: false)
    bluesky  = []
    mastodon = []
    original_bsky  = BlueskyClient.singleton_class.instance_method(:post)
    original_masto = MastodonClient.singleton_class.instance_method(:post)
    BlueskyClient.define_singleton_method(:post) do |text:|
      raise "bsky down" if bluesky_raises

      bluesky << text
    end
    MastodonClient.define_singleton_method(:post) { |text:| mastodon << text }
    yield bluesky, mastodon
  ensure
    BlueskyClient.singleton_class.define_method(:post, original_bsky)
    MastodonClient.singleton_class.define_method(:post, original_masto)
  end

  test "posts the text to every social client" do
    stub_clients do |bluesky, mastodon|
      SocialBroadcast.post("hello world")

      assert_equal [ "hello world" ], bluesky
      assert_equal [ "hello world" ], mastodon
    end
  end

  test "a failing client is non-fatal and does not stop the others or raise" do
    stub_clients(bluesky_raises: true) do |_bluesky, mastodon|
      assert_nothing_raised { SocialBroadcast.post("hello") }

      assert_equal [ "hello" ], mastodon, "Mastodon should still be posted when BlueSky raises"
    end
  end
end
