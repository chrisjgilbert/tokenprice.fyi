require "test_helper"

unless defined?(Anthropic::Errors::Error)
  module Anthropic
    module Errors
      class Error < StandardError; end
    end
  end
end

class AiModel::InsightTest < ActiveSupport::TestCase
  def fake_client(response)
    messages = Object.new
    messages.define_singleton_method(:create) { |**_kwargs| response }

    client = Object.new
    client.define_singleton_method(:messages) { messages }
    client
  end

  def error_client(error)
    messages = Object.new
    messages.define_singleton_method(:create) { |**_kwargs| raise error }

    client = Object.new
    client.define_singleton_method(:messages) { messages }
    client
  end

  def stub_tool_response(so_what:)
    tool_block = Object.new
    tool_block.define_singleton_method(:type)  { :tool_use }
    tool_block.define_singleton_method(:input) { { so_what: so_what } }

    response = Object.new
    response.define_singleton_method(:content) { [ tool_block ] }
    response
  end

  test "returns the so_what prose from the tool call" do
    model = ai_models(:opus)
    client = fake_client(stub_tool_response(so_what: "Frontier reasoning gets meaningfully cheaper."))

    result = AiModel::Insight.new(model, client: client).run

    assert_equal "Frontier reasoning gets meaningfully cheaper.", result[:so_what]
  end

  test "includes name, provider, tier and price in the prompt" do
    model = ai_models(:opus)
    received = nil
    response = stub_tool_response(so_what: "x")
    messages = Object.new
    messages.define_singleton_method(:create) do |**kwargs|
      received = kwargs[:messages].first[:content]
      response
    end
    client = Object.new
    client.define_singleton_method(:messages) { messages }

    AiModel::Insight.new(model, client: client).run

    assert_includes received, model.name
    assert_includes received, model.provider.name
    assert_includes received, "frontier"
  end

  test "raises Error when the Anthropic API raises" do
    model = ai_models(:opus)
    client = error_client(Anthropic::Errors::Error.new("overloaded"))

    error = assert_raises(AiModel::Insight::Error) { AiModel::Insight.new(model, client: client).run }

    assert_match "overloaded", error.message
  end

  test "truncates an over-long so_what" do
    model = ai_models(:opus)
    client = fake_client(stub_tool_response(so_what: "A" * 500))

    result = AiModel::Insight.new(model, client: client).run

    assert_operator result[:so_what].length, :<=, AiModel::Insight::SO_WHAT_LIMIT
  end
end
