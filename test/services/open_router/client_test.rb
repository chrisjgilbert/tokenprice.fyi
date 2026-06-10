require "test_helper"

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

    test "sends a bearer token only when an api key is configured" do
      with_key    = Client.new(api_key: "sk-test")
      without_key = Client.new(api_key: nil)

      assert_equal "sk-test", with_key.instance_variable_get(:@api_key)
      assert_nil without_key.instance_variable_get(:@api_key)
    end
  end
end
