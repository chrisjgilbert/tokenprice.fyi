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

class ModelDescriptionGeneratorTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def make_generator(fake_client)
    generator = ModelDescriptionGenerator.new
    generator.instance_variable_set(:@client, fake_client)
    generator
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

  def valid_input
    {
      description: "A fast multimodal model.",
      strengths:   "Quick responses with a large context window.",
      best_for:    "Latency-sensitive, high-volume features.",
      limitations: "Lighter reasoning than frontier models."
    }
  end

  # ---------------------------------------------------------------------------
  # Test cases
  # ---------------------------------------------------------------------------

  test "returns the four editorial fields from the tool call" do
    generator = make_generator(fake_client(stub_tool_response(valid_input)))

    result = generator.generate(name: "Wonder 1", provider: "NewLab")

    assert_equal "A fast multimodal model.",                  result[:description]
    assert_equal "Quick responses with a large context window.", result[:strengths]
    assert_equal "Latency-sensitive, high-volume features.",  result[:best_for]
    assert_equal "Lighter reasoning than frontier models.",   result[:limitations]
  end

  test "raises GenerateError when the Anthropic API raises an error" do
    api_error = Anthropic::Errors::Error.new("rate limited")
    generator = make_generator(error_client(api_error))

    error = assert_raises(ModelDescriptionGenerator::GenerateError) do
      generator.generate(name: "Wonder 1", provider: "NewLab")
    end

    assert_match "Anthropic API error", error.message
    assert_match "rate limited", error.message
  end

  test "raises GenerateError when the response contains no tool_use block" do
    generator = make_generator(fake_client(stub_text_only_response))

    error = assert_raises(ModelDescriptionGenerator::GenerateError) do
      generator.generate(name: "Wonder 1", provider: "NewLab")
    end

    assert_equal "No tool_use block in response", error.message
  end

  test "clamps each field to its length limit" do
    long = "A" * 500
    generator = make_generator(fake_client(stub_tool_response(
      description: long, strengths: long, best_for: long, limitations: long
    )))

    result = generator.generate(name: "Wonder 1", provider: "NewLab")

    assert_operator result[:description].length, :<=, ModelDescriptionGenerator::DESCRIPTION_LIMIT
    assert_operator result[:strengths].length,   :<=, ModelDescriptionGenerator::FACET_LIMIT
  end

  test "blank fields collapse to nil" do
    generator = make_generator(fake_client(stub_tool_response(
      description: "Real description.", strengths: "  ", best_for: "", limitations: nil
    )))

    result = generator.generate(name: "Wonder 1", provider: "NewLab")

    assert_equal "Real description.", result[:description]
    assert_nil result[:strengths]
    assert_nil result[:best_for]
    assert_nil result[:limitations]
  end

  test "includes context window and source text in the prompt when provided" do
    received_content = nil

    messages = Object.new
    messages.define_singleton_method(:create) do |**kwargs|
      received_content = kwargs[:messages].first[:content]
      tool_block = Object.new
      tool_block.define_singleton_method(:type)  { :tool_use }
      tool_block.define_singleton_method(:input) do
        { description: "d", strengths: "s", best_for: "b", limitations: "l" }
      end
      response = Object.new
      response.define_singleton_method(:content) { [ tool_block ] }
      response
    end
    client = Object.new
    client.define_singleton_method(:messages) { messages }
    generator = make_generator(client)

    generator.generate(
      name: "Wonder 1", provider: "NewLab",
      context_window: 1_000_000, source_text: "An upstream blurb."
    )

    assert_not_nil received_content
    assert_includes received_content, "Wonder 1"
    assert_includes received_content, "NewLab"
    assert_includes received_content, "1000000"
    assert_includes received_content, "An upstream blurb."
  end

  test "omits context window and source text when not provided" do
    received_content = nil

    messages = Object.new
    messages.define_singleton_method(:create) do |**kwargs|
      received_content = kwargs[:messages].first[:content]
      tool_block = Object.new
      tool_block.define_singleton_method(:type)  { :tool_use }
      tool_block.define_singleton_method(:input) do
        { description: "d", strengths: "s", best_for: "b", limitations: "l" }
      end
      response = Object.new
      response.define_singleton_method(:content) { [ tool_block ] }
      response
    end
    client = Object.new
    client.define_singleton_method(:messages) { messages }
    generator = make_generator(client)

    generator.generate(name: "Wonder 1", provider: "NewLab")

    assert_not_nil received_content
    refute_includes received_content, "Context window"
    refute_includes received_content, "Upstream description"
  end
end
