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

  # ---------------------------------------------------------------------------
  # tool_call
  # ---------------------------------------------------------------------------

  TOOL = { name: "do_thing", input_schema: { type: "object" } }.freeze

  def tool_use_response(input_hash)
    block = Object.new
    block.define_singleton_method(:type)  { :tool_use }
    block.define_singleton_method(:input) { input_hash }
    response = Object.new
    response.define_singleton_method(:content) { [ block ] }
    response
  end

  # A fake client capturing the kwargs passed to messages.create.
  def capturing_client(response, into:)
    messages = Object.new
    messages.define_singleton_method(:create) { |**kwargs| into.replace(kwargs); response }
    client = Object.new
    client.define_singleton_method(:messages) { messages }
    client
  end

  def raising_client(error)
    messages = Object.new
    messages.define_singleton_method(:create) { |**_| raise error }
    client = Object.new
    client.define_singleton_method(:messages) { messages }
    client
  end

  test "tool_call returns the tool input and forces the single offered tool" do
    sent = {}
    client = capturing_client(tool_use_response({ ok: true }), into: sent)

    result = AnthropicClient.tool_call(
      model: "m", system: "sys", messages: [ { role: "user", content: "hi" } ],
      tool: TOOL, max_tokens: 64, client: client
    )

    assert_equal({ ok: true }, result)
    assert_equal "sys", sent[:system_]
    assert_equal [ TOOL ], sent[:tools]
    assert_equal({ type: "tool", name: "do_thing" }, sent[:tool_choice])
  end

  test "tool_call raises AnthropicClient::Error when the response has no tool_use block" do
    text = Object.new
    text.define_singleton_method(:type) { :text }
    response = Object.new
    response.define_singleton_method(:content) { [ text ] }
    client = capturing_client(response, into: {})

    error = assert_raises(AnthropicClient::Error) do
      AnthropicClient.tool_call(
        model: "m", system: "sys", messages: [], tool: TOOL, max_tokens: 64, client: client
      )
    end
    assert_equal "No tool_use block in response", error.message
  end

  test "tool_call wraps an Anthropic API error in AnthropicClient::Error" do
    client = raising_client(Anthropic::Errors::Error.new("rate limited"))

    error = assert_raises(AnthropicClient::Error) do
      AnthropicClient.tool_call(
        model: "m", system: "sys", messages: [], tool: TOOL, max_tokens: 64, client: client
      )
    end
    assert_match "Anthropic API error", error.message
    assert_match "rate limited", error.message
  end
end
