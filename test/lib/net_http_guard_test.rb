require "test_helper"

class NetHttpGuardTest < ActiveSupport::TestCase
  # The guard raises before it reaches super, so these assertions never open a
  # real socket.
  test "blocks a real external HTTP connection" do
    error = assert_raises(RuntimeError) do
      Net::HTTP.start("bsky.social", 443, use_ssl: true) { }
    end
    assert_match(/Blocked real HTTP/, error.message)
  end

  test "an un-stubbed social post raises instead of hitting the live API" do
    Rails.application.credentials.define_singleton_method(:bluesky) do
      { handle: "x.bsky.social", app_password: "pw" }
    end
    error = assert_raises(RuntimeError) { BlueskyClient.post(text: "nope") }
    assert_match(/Blocked real HTTP/, error.message)
  ensure
    creds = Rails.application.credentials
    if creds.singleton_methods.include?(:bluesky)
      creds.singleton_class.send(:remove_method, :bluesky)
    end
  end

  # Prove both branches without any real network I/O by driving the guard over a
  # stand-in whose #start stands for the real Net::HTTP#start. A nil address is
  # Capybara's default health-check host and must be forwarded, not blocked.
  test "forwards loopback and nil hosts to super, blocks the rest" do
    probe = Class.new do
      attr_reader :address, :forwarded
      def initialize(address) = @address = address
      def start(*) = @forwarded = true
      prepend BlockExternalHTTPInTests
    end

    assert_raises(RuntimeError) { probe.new("bsky.social").start }

    [ "127.0.0.1", "localhost", "::1", "0.0.0.0", nil ].each do |host|
      instance = probe.new(host)
      instance.start
      assert instance.forwarded, "guard should forward #{host.inspect} to super"
    end
  end
end
