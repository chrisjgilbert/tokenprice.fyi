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

  test "MissingApiKeyError is an AnthropicClient::Error, so callers only need to rescue one class" do
    assert_operator AnthropicClient::MissingApiKeyError, :<, AnthropicClient::Error
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

  # ---------------------------------------------------------------------------
  # search_call
  # ---------------------------------------------------------------------------

  def text_block(text, citations: [])
    block = Object.new
    block.define_singleton_method(:type)      { :text }
    block.define_singleton_method(:text)      { text }
    block.define_singleton_method(:citations) { citations }
    block
  end

  # A non-text block (e.g. a web_search_tool_result) — search_call must skip it
  # without trying to read .text/.citations.
  def server_block
    block = Object.new
    block.define_singleton_method(:type) { :web_search_tool_result }
    block
  end

  def citation_obj(url:, title:)
    c = Object.new
    c.define_singleton_method(:url)   { url }
    c.define_singleton_method(:title) { title }
    c
  end

  def search_response(content, stop_reason: :end_turn)
    response = Object.new
    response.define_singleton_method(:content)     { content }
    response.define_singleton_method(:stop_reason) { stop_reason }
    response
  end

  # Fake client that returns a queue of responses and records each call's kwargs.
  def queue_client(responses, captures:)
    queue = responses.dup
    messages = Object.new
    messages.define_singleton_method(:create) { |**kwargs| captures << kwargs; queue.shift }
    client = Object.new
    client.define_singleton_method(:messages) { messages }
    client
  end

  test "search_call returns prose, deduped citations, and offers the web search tool" do
    captures = []
    src = citation_obj(url: "https://example.com/a", title: "A")
    response = search_response([
      server_block,
      text_block("It matters because ", citations: [ src ]),
      text_block("prices fell.", citations: [ src, citation_obj(url: "https://example.com/b", title: "B") ])
    ])
    client = queue_client([ response ], captures: captures)

    result = AnthropicClient.search_call(
      model: "claude-sonnet-5", system: "sys",
      messages: [ { role: "user", content: "why" } ], max_tokens: 256, client: client
    )

    assert_equal "It matters because prices fell.", result[:text]
    assert_equal(
      [ { "url" => "https://example.com/a", "title" => "A" },
        { "url" => "https://example.com/b", "title" => "B" } ],
      result[:citations]
    )
    assert_equal "web_search_20260209", captures.first[:tools].first[:type]
    assert_nil captures.first[:tool_choice]
  end

  test "search_call dedupes citations by url and drops non-http links" do
    captures = []
    response = search_response([
      text_block("a", citations: [ citation_obj(url: "https://example.com/a", title: "A") ]),
      text_block("b", citations: [
        citation_obj(url: "https://example.com/a", title: nil),          # same url, different title
        citation_obj(url: "javascript:alert(1)", title: "evil") ])       # non-http, must be dropped
    ])
    client = queue_client([ response ], captures: captures)

    result = AnthropicClient.search_call(
      model: "m", system: "sys", messages: [ { role: "user", content: "why" } ],
      max_tokens: 256, client: client
    )

    assert_equal [ { "url" => "https://example.com/a", "title" => "A" } ], result[:citations]
  end

  test "search_call resumes on pause_turn and accumulates across turns" do
    captures = []
    first  = search_response([ text_block("Part one. ",
      citations: [ citation_obj(url: "https://example.com/a", title: "A") ]) ], stop_reason: :pause_turn)
    second = search_response([ text_block("Part two.",
      citations: [ citation_obj(url: "https://example.com/b", title: "B") ]) ], stop_reason: :end_turn)
    client = queue_client([ first, second ], captures: captures)

    result = AnthropicClient.search_call(
      model: "m", system: "sys", messages: [ { role: "user", content: "why" } ],
      max_tokens: 256, client: client
    )

    assert_equal "Part one. Part two.", result[:text]
    assert_equal 2, result[:citations].size
    # The resume re-sends the conversation with the prior assistant turn appended.
    assert_equal 2, captures.size
    assert_equal "assistant", captures.last[:messages].last[:role]
  end

  test "search_call stops resuming after max_continuations" do
    captures = []
    forever = -> { search_response([ text_block("x") ], stop_reason: :pause_turn) }
    client = queue_client(Array.new(10) { forever.call }, captures: captures)

    result = AnthropicClient.search_call(
      model: "m", system: "sys", messages: [ { role: "user", content: "why" } ],
      max_tokens: 256, max_continuations: 2, client: client
    )

    # Initial call plus exactly max_continuations resumes — no runaway loop.
    assert_equal 3, captures.size
    assert_equal "xxx", result[:text]
  end

  test "search_call wraps an Anthropic API error" do
    client = raising_client(Anthropic::Errors::Error.new("overloaded"))

    error = assert_raises(AnthropicClient::Error) do
      AnthropicClient.search_call(
        model: "m", system: "sys", messages: [], max_tokens: 256, client: client
      )
    end
    assert_match "Anthropic API error", error.message
    assert_match "overloaded", error.message
  end
end
