require "test_helper"

unless defined?(Anthropic::Errors::Error)
  module Anthropic
    module Errors
      class Error < StandardError; end
    end
  end
end

class AiModel::InsightTest < ActiveSupport::TestCase
  test "returns the so_what prose from the tool call" do
    model = ai_models(:opus)
    client = fake_anthropic_tool_client(input: { so_what: "Frontier reasoning gets meaningfully cheaper." })

    result = AiModel::Insight.new(model, client: client).run

    assert_equal "Frontier reasoning gets meaningfully cheaper.", result[:so_what]
  end

  test "includes name, provider, tier and price in the prompt" do
    model = ai_models(:opus)
    sent = {}
    client = fake_anthropic_tool_client(input: { so_what: "x" }, into: sent)

    AiModel::Insight.new(model, client: client).run

    received = sent[:messages].first[:content]
    assert_includes received, model.name
    assert_includes received, model.provider.name
    assert_includes received, "frontier"
  end

  test "raises Error when the Anthropic API raises" do
    model = ai_models(:opus)
    client = fake_anthropic_tool_client(raises: Anthropic::Errors::Error.new("overloaded"))

    error = assert_raises(AiModel::Insight::Error) { AiModel::Insight.new(model, client: client).run }

    assert_match "overloaded", error.message
  end

  test "truncates an over-long so_what" do
    model = ai_models(:opus)
    client = fake_anthropic_tool_client(input: { so_what: "A" * 500 })

    result = AiModel::Insight.new(model, client: client).run

    assert_operator result[:so_what].length, :<=, SoWhat::LIMIT
  end
end
