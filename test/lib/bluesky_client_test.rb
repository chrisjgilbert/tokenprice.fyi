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

class BlueskyClientTest < ActiveSupport::TestCase
  # Stub the nested bluesky credential for the duration of the block by defining
  # a singleton method on the (memoized) credentials object, then removing it to
  # restore the normal method_missing lookup.
  def with_bluesky_credentials(handle:, app_password:)
    creds = Rails.application.credentials
    value = if handle.nil? && app_password.nil?
              nil
    else
              { handle: handle, app_password: app_password }
    end
    creds.define_singleton_method(:bluesky) { value }
    yield
  ensure
    creds.singleton_class.send(:remove_method, :bluesky)
  end

  test "no-op when credential is not set" do
    http_called = false
    with_bluesky_credentials(handle: nil, app_password: nil) do
      Net::HTTP.stub_new(Object.new.tap { |o|
        o.define_singleton_method(:method_missing) { |*| http_called = true }
      }) do
        assert_nil BlueskyClient.post(text: "hello")
      end
    end

    assert_equal false, http_called, "expected no HTTP call when credential is unset"
  end

  test "no-op when app_password is blank" do
    http_called = false
    with_bluesky_credentials(handle: "alice.bsky.social", app_password: "") do
      Net::HTTP.stub_new(Object.new.tap { |o|
        o.define_singleton_method(:method_missing) { |*| http_called = true }
      }) do
        assert_nil BlueskyClient.post(text: "hello")
      end
    end

    assert_equal false, http_called, "expected no HTTP call when app_password is blank"
  end

  test "posts session then record with expected bodies and auth" do
    requests = []

    session_response = Net::HTTPSuccess.new("1.1", "200", "OK")
    session_response.define_singleton_method(:body) { '{"accessJwt":"jwt-123","did":"did:plc:abc"}' }
    record_response = Net::HTTPSuccess.new("1.1", "200", "OK")
    record_response.define_singleton_method(:body) { '{"uri":"at://record"}' }

    fake_http = build_sequential_http([ session_response, record_response ]) do |req|
      requests << { path: req.path, body: req.body, ct: req["Content-Type"], auth: req["Authorization"] }
    end

    with_bluesky_credentials(handle: "alice.bsky.social", app_password: "app-pw") do
      Net::HTTP.stub_new(fake_http) do
        assert_equal record_response, BlueskyClient.post(text: "hello world")
      end
    end

    assert_equal 2, requests.size

    session_req = requests[0]
    assert_equal "/xrpc/com.atproto.server.createSession", session_req[:path]
    assert_equal "application/json", session_req[:ct]
    assert_equal({ "identifier" => "alice.bsky.social", "password" => "app-pw" },
                 JSON.parse(session_req[:body]))

    record_req = requests[1]
    assert_equal "/xrpc/com.atproto.repo.createRecord", record_req[:path]
    assert_equal "application/json", record_req[:ct]
    assert_equal "Bearer jwt-123", record_req[:auth]
    parsed = JSON.parse(record_req[:body])
    assert_equal "did:plc:abc", parsed["repo"]
    assert_equal "app.bsky.feed.post", parsed["collection"]
    assert_equal "app.bsky.feed.post", parsed.dig("record", "$type")
    assert_equal "hello world", parsed.dig("record", "text")
    assert parsed.dig("record", "createdAt").present?
  end

  test "raises when createSession returns non-2xx" do
    error_response = Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized")
    error_response.define_singleton_method(:body) { "bad credentials" }

    fake_http = build_sequential_http([ error_response ])

    error = nil
    with_bluesky_credentials(handle: "alice.bsky.social", app_password: "app-pw") do
      Net::HTTP.stub_new(fake_http) do
        error = assert_raises(RuntimeError) { BlueskyClient.post(text: "hello") }
      end
    end

    assert_match(/401/, error.message)
  end

  test "raises when createRecord returns non-2xx" do
    session_response = Net::HTTPSuccess.new("1.1", "200", "OK")
    session_response.define_singleton_method(:body) { '{"accessJwt":"jwt-123","did":"did:plc:abc"}' }
    error_response = Net::HTTPServerError.new("1.1", "500", "Internal Server Error")
    error_response.define_singleton_method(:body) { "boom" }

    fake_http = build_sequential_http([ session_response, error_response ])

    error = nil
    with_bluesky_credentials(handle: "alice.bsky.social", app_password: "app-pw") do
      Net::HTTP.stub_new(fake_http) do
        error = assert_raises(RuntimeError) { BlueskyClient.post(text: "hello") }
      end
    end

    assert_match(/500/, error.message)
  end

  private

  # Build a fake Net::HTTP instance whose #start yields self and whose #request
  # returns each response in order, one per call. An optional block receives the
  # request. See slack_notifier_test.rb for why timeouts aren't stubbed.
  def build_sequential_http(responses, &on_request)
    queue = responses.dup
    fake = Object.new
    fake.define_singleton_method(:use_ssl=) { |_| }
    fake.define_singleton_method(:start) { |&blk| blk ? blk.call(fake) : fake }
    fake.define_singleton_method(:request) do |req|
      on_request&.call(req)
      queue.shift
    end
    fake
  end
end
