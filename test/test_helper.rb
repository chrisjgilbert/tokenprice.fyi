ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Inject a dummy Anthropic API key so AnthropicClient.build's guard passes
    # in tests that construct the real client. Like admin_password_digest, this
    # keeps tests from depending on the master key being present (it isn't on CI).
    def stub_anthropic_key!(key = "sk-ant-test-key")
      Rails.application.credentials.define_singleton_method(:anthropic_api_key) { key }
    end

    # Build a fake Anthropic client whose web-search response yields the given
    # text and citations (as SDK-shaped objects), for AnthropicClient.search_call.
    # `citations` is an array of { url:, title: }; pass `into:` to capture the
    # create kwargs, or `raises:` to simulate an API failure.
    def fake_anthropic_search_client(text: "x", citations: [], into: nil, raises: nil)
      block = Object.new
      block.define_singleton_method(:type) { :text }
      block.define_singleton_method(:text) { text }
      block.define_singleton_method(:citations) do
        citations.map { |c| Struct.new(:url, :title).new(c[:url], c[:title]) }
      end
      response = Object.new
      response.define_singleton_method(:content)     { [ block ] }
      response.define_singleton_method(:stop_reason) { :end_turn }
      messages = Object.new
      messages.define_singleton_method(:create) do |**kwargs|
        into&.replace(kwargs)
        raises ? (raise raises) : response
      end
      client = Object.new
      client.define_singleton_method(:messages) { messages }
      client
    end

    teardown do
      creds = Rails.application.credentials
      if creds.singleton_methods.include?(:anthropic_api_key)
        creds.singleton_class.send(:remove_method, :anthropic_api_key)
      end
    end
  end
end

# Admin auth helpers. The login password's bcrypt digest normally lives in
# encrypted credentials; tests inject a known digest so they don't depend on
# the master key being present (it isn't on CI).
ADMIN_TEST_PASSWORD = "test-password-123"
ADMIN_TEST_DIGEST = BCrypt::Password.create(ADMIN_TEST_PASSWORD).to_s

class ActionDispatch::IntegrationTest
  # Override the credentials accessor directly — `credentials` memoizes its
  # options at boot, so mutating the underlying hash afterwards isn't seen.
  def stub_admin_digest!(digest = ADMIN_TEST_DIGEST)
    Rails.application.credentials.define_singleton_method(:admin_password_digest) { digest }
  end

  def sign_in_admin
    stub_admin_digest!
    post admin_login_path, params: { password: ADMIN_TEST_PASSWORD }
  end

  # Remove the per-test digest override so it can't leak into a later test
  # in the same process.
  teardown do
    creds = Rails.application.credentials
    if creds.singleton_methods.include?(:admin_password_digest)
      creds.singleton_class.send(:remove_method, :admin_password_digest)
    end
  end
end
