require "test_helper"
require "net/http"

# Same helper defined in slack_notifier_test.rb — extending again is idempotent.
unless Net::HTTP.respond_to?(:stub_new)
  module NetHttpStub
    def stub_new(replacement)
      original = singleton_class.instance_method(:new)
      define_singleton_method(:new) { |*, **| replacement }
      yield
    ensure
      singleton_class.define_method(:new, original)
    end
  end
  Net::HTTP.extend(NetHttpStub)
end

class MastodonClientTest < ActiveSupport::TestCase
  # Stub the nested mastodon credential for the duration of the block by defining
  # a singleton method on the (memoized) credentials object, then removing it to
  # restore the normal method_missing lookup.
  def with_mastodon_credentials(instance_url:, access_token:)
    creds = Rails.application.credentials
    value = if instance_url.nil? && access_token.nil?
              nil
    else
              { instance_url: instance_url, access_token: access_token }
    end
    creds.define_singleton_method(:mastodon) { value }
    yield
  ensure
    creds.singleton_class.send(:remove_method, :mastodon)
  end

  test "no-op when credential is not set" do
    http_called = false
    with_mastodon_credentials(instance_url: nil, access_token: nil) do
      Net::HTTP.stub_new(Object.new.tap { |o|
        o.define_singleton_method(:method_missing) { |*| http_called = true }
      }) do
        assert_nil MastodonClient.post(text: "hello")
      end
    end

    assert_equal false, http_called, "expected no HTTP call when credential is unset"
  end

  test "no-op when access_token is blank" do
    http_called = false
    with_mastodon_credentials(instance_url: "https://mastodon.social", access_token: "") do
      Net::HTTP.stub_new(Object.new.tap { |o|
        o.define_singleton_method(:method_missing) { |*| http_called = true }
      }) do
        assert_nil MastodonClient.post(text: "hello")
      end
    end

    assert_equal false, http_called, "expected no HTTP call when access_token is blank"
  end

  test "posts status JSON to the statuses endpoint with bearer auth" do
    captured = {}

    stub_response = Net::HTTPSuccess.new("1.1", "200", "OK")
    stub_response.define_singleton_method(:body) { '{"id":"1"}' }

    fake_http = build_fake_http(stub_response) do |req|
      captured[:path] = req.path
      captured[:body] = req.body
      captured[:ct]   = req["Content-Type"]
      captured[:auth] = req["Authorization"]
    end

    with_mastodon_credentials(instance_url: "https://mastodon.social", access_token: "tok-abc") do
      Net::HTTP.stub_new(fake_http) do
        assert_equal stub_response, MastodonClient.post(text: "hello world")
      end
    end

    assert_equal "/api/v1/statuses", captured[:path]
    assert_equal "application/json", captured[:ct]
    assert_equal "Bearer tok-abc", captured[:auth]
    assert_equal({ "status" => "hello world" }, JSON.parse(captured[:body]))
  end

  test "raises on non-2xx response" do
    stub_response = Net::HTTPServerError.new("1.1", "500", "Internal Server Error")
    stub_response.define_singleton_method(:body) { "boom" }

    fake_http = build_fake_http(stub_response)

    error = nil
    with_mastodon_credentials(instance_url: "https://mastodon.social", access_token: "tok-abc") do
      Net::HTTP.stub_new(fake_http) do
        error = assert_raises(RuntimeError) { MastodonClient.post(text: "hello") }
      end
    end

    assert_match(/500/, error.message)
  end

  test "rejects a non-https instance URL without making a request" do
    http_called = false
    fake_http = Object.new.tap do |o|
      o.define_singleton_method(:method_missing) { |*| http_called = true }
    end

    error = nil
    with_mastodon_credentials(instance_url: "http://mastodon.social", access_token: "tok-abc") do
      Net::HTTP.stub_new(fake_http) do
        error = assert_raises(RuntimeError) { MastodonClient.post(text: "hello") }
      end
    end

    assert_match(/https/, error.message)
    assert_equal false, http_called, "expected no HTTP call for a non-https instance URL"
  end

  private

  # Build a fake Net::HTTP instance whose #start yields self and whose #request
  # returns `stub_response`. See slack_notifier_test.rb for why timeouts aren't
  # stubbed.
  def build_fake_http(stub_response, &on_request)
    fake = Object.new
    fake.define_singleton_method(:use_ssl=) { |_| }
    fake.define_singleton_method(:start) { |&blk| blk ? blk.call(fake) : fake }
    fake.define_singleton_method(:request) do |req|
      on_request&.call(req)
      stub_response
    end
    fake
  end
end
