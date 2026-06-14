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

class NewsClassifierTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def make_classifier(fake_client)
    classifier = NewsClassifier.new
    classifier.instance_variable_set(:@client, fake_client)
    classifier
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
    classifier = make_classifier(fake_client(stub_tool_response(input)))

    result = classifier.classify(title: "OpenAI releases GPT-5", source: "openai.com")

    assert_equal true,      result[:relevant]
    assert_equal "release", result[:kind]
    assert_equal "New LLM model announcement.", result[:rationale]
  end

  test "returns relevant: false for an irrelevant headline" do
    input = { relevant: false, kind: "other", rationale: "Sports news, not related to LLM pricing." }
    classifier = make_classifier(fake_client(stub_tool_response(input)))

    result = classifier.classify(title: "Team wins championship", source: "sports.com")

    assert_equal false,   result[:relevant]
    assert_equal "other", result[:kind]
    assert_includes result[:rationale], "Sports news"
  end

  test "raises ClassifyError when Anthropic API raises an error" do
    api_error = Anthropic::Errors::Error.new("rate limited")
    classifier = make_classifier(error_client(api_error))

    error = assert_raises(NewsClassifier::ClassifyError) do
      classifier.classify(title: "Any headline", source: "any.com")
    end

    assert_match "Anthropic API error", error.message
    assert_match "rate limited", error.message
  end

  test "raises ClassifyError when response contains no tool_use block" do
    classifier = make_classifier(fake_client(stub_text_only_response))

    error = assert_raises(NewsClassifier::ClassifyError) do
      classifier.classify(title: "Any headline", source: "any.com")
    end

    assert_equal "No tool_use block in response", error.message
  end

  test "includes body context in the message when provided" do
    received_content = nil

    messages = Object.new
    messages.define_singleton_method(:create) do |**kwargs|
      received_content = kwargs[:messages].first[:content]
      # Return a valid tool response so the method completes
      input = { relevant: false, kind: "other", rationale: "Not relevant." }
      tool_block = Object.new
      tool_block.define_singleton_method(:type)  { :tool_use }
      tool_block.define_singleton_method(:input) { input }
      response = Object.new
      response.define_singleton_method(:content) { [ tool_block ] }
      response
    end

    client = Object.new
    client.define_singleton_method(:messages) { messages }
    classifier = make_classifier(client)

    classifier.classify(
      title:  "Some headline",
      source: "some.com",
      body:   "This is a detailed article body that provides context."
    )

    assert_not_nil received_content
    assert_includes received_content, "Context:"
    assert_includes received_content, "This is a detailed article body"
  end

  test "truncates rationale to 200 characters" do
    long_rationale = "A" * 250
    input = { relevant: true, kind: "market", rationale: long_rationale }
    classifier = make_classifier(fake_client(stub_tool_response(input)))

    result = classifier.classify(title: "Some headline", source: "some.com")

    assert result[:rationale].length <= 200
  end

  test ".classify delegates to instance classify" do
    stub_anthropic_key!
    input = { relevant: true, kind: "price", rationale: "Price cut." }
    response = stub_tool_response(input)

    # Stub Anthropic::Client.new to return our fake client
    original_new = Anthropic::Client.method(:new)
    fake = fake_client(response)
    Anthropic::Client.define_singleton_method(:new) { |**_| fake }

    begin
      result = NewsClassifier.classify(title: "GPT-4 price cut", source: "openai.com")
      assert_equal true,    result[:relevant]
      assert_equal "price", result[:kind]
    ensure
      # Restore original .new
      Anthropic::Client.singleton_class.send(:remove_method, :new)
      Anthropic::Client.define_singleton_method(:new) { |**opts| original_new.call(**opts) }
    end
  end
end
