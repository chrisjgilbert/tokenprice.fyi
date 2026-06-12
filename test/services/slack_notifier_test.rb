require "test_helper"
require "net/http"

# Same helper defined in client_test.rb — extending again is idempotent.
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

class SlackNotifierTest < ActiveSupport::TestCase
  setup    { @original = ENV["SLACK_WEBHOOK_URL"] }
  teardown { ENV["SLACK_WEBHOOK_URL"] = @original }

  test "no-op when webhook URL is not set" do
    ENV["SLACK_WEBHOOK_URL"] = nil

    # Ensure no HTTP call is attempted by monitoring Net::HTTP.new directly.
    http_called = false
    Net::HTTP.stub_new(Object.new.tap { |o|
      o.define_singleton_method(:method_missing) { |*| http_called = true }
    }) do
      result = SlackNotifier.post({ text: "hello" })
      assert_nil result
    end

    assert_equal false, http_called, "expected no HTTP call when URL is unset"
  end

  test "posts JSON payload to webhook URL" do
    ENV["SLACK_WEBHOOK_URL"] = "https://hooks.slack.com/services/test"
    payload = { text: "hello" }

    captured_body   = nil
    captured_ct     = nil

    stub_response = Net::HTTPSuccess.new("1.1", "200", "OK")
    stub_response.define_singleton_method(:body) { '{"ok": true}' }

    fake_http = build_fake_http(stub_response) do |req|
      captured_body = req.body
      captured_ct   = req["Content-Type"]
    end

    Net::HTTP.stub_new(fake_http) do
      result = SlackNotifier.post(payload)
      assert_equal stub_response, result
    end

    assert_equal payload.to_json, captured_body
    assert_equal "application/json", captured_ct
  end

  test "raises on non-2xx response" do
    ENV["SLACK_WEBHOOK_URL"] = "https://hooks.slack.com/services/test"

    stub_response = Net::HTTPServerError.new("1.1", "500", "Internal Server Error")
    stub_response.define_singleton_method(:body) { "error" }

    fake_http = build_fake_http(stub_response)

    Net::HTTP.stub_new(fake_http) do
      assert_raises(RuntimeError) { SlackNotifier.post({ text: "hello" }) }
    end
  end

  private

  # Build a fake Net::HTTP instance whose #start yields self and whose
  # #request returns `stub_response`. An optional block receives the request.
  def build_fake_http(stub_response, &on_request)
    fake = Object.new
    fake.define_singleton_method(:use_ssl=)      { |_| }
    fake.define_singleton_method(:open_timeout=) { |_| }
    fake.define_singleton_method(:read_timeout=) { |_| }
    fake.define_singleton_method(:start) { |&blk| blk ? blk.call(fake) : fake }
    fake.define_singleton_method(:request) do |req|
      on_request&.call(req)
      stub_response
    end
    fake
  end
end
