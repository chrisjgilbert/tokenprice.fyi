require "test_helper"

# Ensure Anthropic::Errors::Error exists for error stubs even if the gem
# is not fully loaded in the test environment.
unless defined?(Anthropic::Errors::Error)
  module Anthropic
    module Errors
      class Error < StandardError; end
      class APIError < Error; end
    end
  end
end

class NewsItem::ClassificationTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def make_classification(fake_client, news_item)
    NewsItem::Classification.new(news_item, client: fake_client)
  end

  # A plain stand-in for a persisted NewsItem responding to the attributes the
  # classification reads.
  def stub_news_item(title:, source:, excerpt: nil)
    item = Object.new
    item.define_singleton_method(:title)   { title }
    item.define_singleton_method(:source)  { source }
    item.define_singleton_method(:excerpt) { excerpt }
    item
  end

  # Build a fake tool_use response block whose .type returns the Symbol :tool_use.
  def stub_tool_response(input_hash)
    tool_block = Object.new
    tool_block.define_singleton_method(:type)  { :tool_use }
    tool_block.define_singleton_method(:input) { input_hash }

    response = Object.new
    response.define_singleton_method(:content) { [ tool_block ] }
    response
  end

  # Build a fake response with no tool_use block (e.g. only a text block).
  def stub_text_only_response
    text_block = Object.new
    text_block.define_singleton_method(:type) { :text }

    response = Object.new
    response.define_singleton_method(:content) { [ text_block ] }
    response
  end

  # Build a fake Anthropic client that returns the given response.
  def fake_client(response)
    messages = Object.new
    messages.define_singleton_method(:create) { |**_kwargs| response }

    client = Object.new
    client.define_singleton_method(:messages) { messages }
    client
  end

  # Build a fake client whose messages.create raises the given error.
  def error_client(error)
    messages = Object.new
    messages.define_singleton_method(:create) { |**_kwargs| raise error }

    client = Object.new
    client.define_singleton_method(:messages) { messages }
    client
  end

  # ---------------------------------------------------------------------------
  # Test cases
  # ---------------------------------------------------------------------------

  test "returns relevant: true for a relevant headline" do
    input = { relevant: true, kind: "release", rationale: "New LLM model announcement." }
    item = stub_news_item(title: "OpenAI releases GPT-5", source: "openai.com")
    classification = make_classification(fake_client(stub_tool_response(input)), item)

    result = classification.run

    assert_equal true,      result[:relevant]
    assert_equal "release", result[:kind]
    assert_equal "New LLM model announcement.", result[:rationale]
  end

  test "returns relevant: false for an irrelevant headline" do
    input = { relevant: false, kind: "other", rationale: "Sports news, not related to LLM pricing." }
    item = stub_news_item(title: "Team wins championship", source: "sports.com")
    classification = make_classification(fake_client(stub_tool_response(input)), item)

    result = classification.run

    assert_equal false,   result[:relevant]
    assert_equal "other", result[:kind]
    assert_includes result[:rationale], "Sports news"
  end

  test "raises Error when Anthropic API raises an error" do
    api_error = Anthropic::Errors::Error.new("rate limited")
    item = stub_news_item(title: "Any headline", source: "any.com")
    classification = make_classification(error_client(api_error), item)

    error = assert_raises(NewsItem::Classification::Error) do
      classification.run
    end

    assert_match "Anthropic API error", error.message
    assert_match "rate limited", error.message
  end

  test "raises Error when response contains no tool_use block" do
    item = stub_news_item(title: "Any headline", source: "any.com")
    classification = make_classification(fake_client(stub_text_only_response), item)

    error = assert_raises(NewsItem::Classification::Error) do
      classification.run
    end

    assert_equal "No tool_use block in response", error.message
  end

  # A fake client whose messages.create captures the prompt content sent to it
  # (into `captured`, an array so the block can mutate it by reference) and
  # returns a canned tool response.
  def capturing_client(captured, response_input)
    tool_block = Object.new
    tool_block.define_singleton_method(:type)  { :tool_use }
    tool_block.define_singleton_method(:input) { response_input }
    response = Object.new
    response.define_singleton_method(:content) { [ tool_block ] }

    messages = Object.new
    messages.define_singleton_method(:create) do |**kwargs|
      captured[0] = kwargs[:messages].first[:content]
      response
    end
    client = Object.new
    client.define_singleton_method(:messages) { messages }
    client
  end

  test "includes the excerpt in the prompt content when present" do
    captured = [ nil ]
    client = capturing_client(captured, relevant: true, kind: "release", rationale: "ok")

    item = stub_news_item(title: "GPT-5.6, Muse Spark 1.1, ChatGPT Work", source: "tldr_ai",
                           excerpt: "Full digest text mentioning Muse Spark 1.1 buried in here.")
    make_classification(client, item).run

    assert_includes captured[0], "Excerpt:"
    assert_includes captured[0], "Muse Spark 1.1 buried in here"
  end

  test "omits the excerpt section entirely when the item has none" do
    captured = [ nil ]
    client = capturing_client(captured, relevant: true, kind: "release", rationale: "ok")

    item = stub_news_item(title: "Some headline", source: "hn", excerpt: nil)
    make_classification(client, item).run

    assert_not_includes captured[0], "Excerpt:"
  end

  test "truncates the excerpt sent to the classifier" do
    captured = [ nil ]
    client = capturing_client(captured, relevant: true, kind: "other", rationale: "ok")

    item = stub_news_item(title: "Some headline", source: "ainews", excerpt: "A" * 30_000)
    make_classification(client, item).run

    excerpt_sent = captured[0].split("Excerpt:\n").last
    assert_equal NewsItem::Classification::EXCERPT_CHARS, excerpt_sent.length
  end

  test "truncates rationale to 200 characters" do
    long_rationale = "A" * 250
    input = { relevant: true, kind: "market", rationale: long_rationale }
    item = stub_news_item(title: "Some headline", source: "some.com")
    classification = make_classification(fake_client(stub_tool_response(input)), item)

    result = classification.run

    assert result[:rationale].length <= 200
  end

  test "builds the Anthropic client via AnthropicClient.build when none is injected" do
    stub_anthropic_key!
    input = { relevant: true, kind: "price", rationale: "Price cut." }
    response = stub_tool_response(input)

    # Stub Anthropic::Client.new to return our fake client
    original_new = Anthropic::Client.method(:new)
    fake = fake_client(response)
    Anthropic::Client.define_singleton_method(:new) { |**_| fake }

    begin
      item = stub_news_item(title: "GPT-4 price cut", source: "openai.com")
      result = NewsItem::Classification.new(item).run
      assert_equal true,    result[:relevant]
      assert_equal "price", result[:kind]
    ensure
      # Restore original .new
      Anthropic::Client.singleton_class.send(:remove_method, :new)
      Anthropic::Client.define_singleton_method(:new) { |**opts| original_new.call(**opts) }
    end
  end
end
