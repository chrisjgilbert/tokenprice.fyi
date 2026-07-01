require "test_helper"

unless defined?(Anthropic::Errors::Error)
  module Anthropic
    module Errors
      class Error < StandardError; end
    end
  end
end

class AiModelInsightJobTest < ActiveJob::TestCase
  def model
    @model ||= ai_models(:opus)
  end

  def stub_anthropic(so_what: "x", raises: nil)
    stub_anthropic_key!
    fake = fake_anthropic_tool_client(input: { so_what: so_what }, raises: raises)
    Anthropic::Client.define_singleton_method(:new) { |**_| fake }
  end

  teardown do
    if Anthropic::Client.singleton_class.instance_methods(false).include?(:new)
      Anthropic::Client.singleton_class.remove_method(:new)
    end
  end

  test "generates and persists the insight for the model" do
    stub_anthropic(so_what: "Frontier reasoning gets meaningfully cheaper.")

    AiModelInsightJob.perform_now(model)
    model.reload

    assert_equal "Frontier reasoning gets meaningfully cheaper.", model.so_what
    assert model.so_what_generated_at.present?
  end

  test "swallows an insight error without raising or persisting" do
    stub_anthropic(raises: Anthropic::Errors::Error.new("overloaded"))

    assert_nothing_raised { AiModelInsightJob.perform_now(model) }
    assert_nil model.reload.so_what
  end

  # No client injected and no key stubbed, so AnthropicClient.build hits its
  # real credential guard — exercises the actual missing-key path end to end,
  # not just the class hierarchy.
  test "swallows a missing API key error without raising or persisting" do
    assert_nothing_raised { AiModelInsightJob.perform_now(model) }
    assert_nil model.reload.so_what
  end
end
