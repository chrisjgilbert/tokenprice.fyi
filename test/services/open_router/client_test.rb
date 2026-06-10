require "test_helper"
require "net/http"

module OpenRouter
  class ClientTest < ActiveSupport::TestCase
    test "models returns the data array" do
      client = Client.new
      client.define_singleton_method(:request_json) do |path|
        raise "unexpected path #{path}" unless path == "/models"
        { "data" => [ { "id" => "anthropic/claude-3.5-sonnet" } ] }
      end

      assert_equal [ { "id" => "anthropic/claude-3.5-sonnet" } ], client.models
    end

    test "models raises when the payload has no data array" do
      client = Client.new
      client.define_singleton_method(:request_json) { |_path| { "error" => "nope" } }

      assert_raises(Client::Error) { client.models }
    end

    # --- request_json: the real Net::HTTP wiring (transport stubbed) --------

    test "models parses a successful HTTP response end to end" do
      body = JSON.generate("data" => [ { "id" => "anthropic/claude-3.5-sonnet" } ])
      with_stubbed_http(http_response(Net::HTTPOK, "200", body)) do |_captured|
        assert_equal [ { "id" => "anthropic/claude-3.5-sonnet" } ], Client.new.models
      end
    end

    test "a non-2xx response raises Error" do
      with_stubbed_http(http_response(Net::HTTPInternalServerError, "500", "boom")) do
        assert_raises(Client::Error) { Client.new.models }
      end
    end

    test "invalid JSON raises Error" do
      with_stubbed_http(http_response(Net::HTTPOK, "200", "not json")) do
        assert_raises(Client::Error) { Client.new.models }
      end
    end

    test "a connection failure raises Error" do
      raising = Object.new
      def raising.method_missing(*) = self
      def raising.respond_to_missing?(*) = true
      def raising.request(*) = raise(SocketError, "getaddrinfo failed")

      Net::HTTP.stub_new(raising) do
        assert_raises(Client::Error) { Client.new.models }
      end
    end

    test "sends an Authorization header only when an api key is configured" do
      body = JSON.generate("data" => [])

      with_stubbed_http(http_response(Net::HTTPOK, "200", body)) do |captured|
        Client.new(api_key: "sk-test").models
        assert_equal "Bearer sk-test", captured[:request]["Authorization"]
      end

      with_stubbed_http(http_response(Net::HTTPOK, "200", body)) do |captured|
        Client.new(api_key: nil).models
        assert_nil captured[:request]["Authorization"]
      end
    end

    private

    # A real Net::HTTPResponse subclass instance with a canned body, so
    # `is_a?(Net::HTTPSuccess)` reflects the status the way the client checks it.
    def http_response(klass, code, body)
      response = klass.new("1.1", code, klass.name)
      response.define_singleton_method(:body) { body }
      response
    end

    # Swap Net::HTTP.new for a fake transport that records the request and
    # returns `response`. Restores the original method afterwards.
    def with_stubbed_http(response)
      captured = {}
      fake = Object.new
      fake.define_singleton_method(:use_ssl=) { |_| }
      fake.define_singleton_method(:open_timeout=) { |_| }
      fake.define_singleton_method(:read_timeout=) { |_| }
      fake.define_singleton_method(:request) { |req| captured[:request] = req; response }

      Net::HTTP.stub_new(fake) { yield captured }
    end
  end
end

# Minitest 6 dropped Object#stub, so provide the one swap we need: replace
# Net::HTTP.new for the duration of a block and restore it after.
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
