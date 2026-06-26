require "test_helper"

class AnthropicClientTest < ActiveSupport::TestCase
  # Override the credentials accessor directly, mirroring how test_helper stubs
  # admin_password_digest — `credentials` memoizes at boot, so we redefine the
  # reader rather than mutate the underlying hash.
  def with_credential(value)
    creds = Rails.application.credentials
    creds.define_singleton_method(:anthropic_api_key) { value }
    yield
  ensure
    if creds.singleton_methods.include?(:anthropic_api_key)
      creds.singleton_class.send(:remove_method, :anthropic_api_key)
    end
  end

  test "raises a clear error when the credential is unset" do
    with_credential(nil) do
      error = assert_raises(AnthropicClient::MissingApiKeyError) { AnthropicClient.build }
      assert_match(/anthropic_api_key/, error.message)
    end
  end

  test "raises a clear error when the credential is blank" do
    with_credential("   ") do
      assert_raises(AnthropicClient::MissingApiKeyError) { AnthropicClient.build }
    end
  end

  test "returns an Anthropic::Client when the credential is present" do
    with_credential("sk-ant-test-key") do
      assert_instance_of Anthropic::Client, AnthropicClient.build
    end
  end
end
