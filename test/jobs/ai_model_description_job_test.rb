require "test_helper"

# Ensure the SDK's error base exists for the failure stub even if the gem
# isn't fully loaded in the test environment (mirrors the insight job test).
unless defined?(Anthropic::Errors::Error)
  module Anthropic
    module Errors
      class Error < StandardError; end
    end
  end
end

class AiModelDescriptionJobTest < ActiveJob::TestCase
  def model
    @model ||= ai_models(:opus)
  end

  def stub_anthropic(input: default_input, raises: nil)
    stub_anthropic_key!
    fake = fake_anthropic_tool_client(input: input, raises: raises)
    Anthropic::Client.define_singleton_method(:new) { |**_| fake }
  end

  def default_input
    { description: "A frontier reasoning model.", strengths: "Reasoning.",
      best_for: "Hard tasks.", limitations: "Costly on simple prompts." }
  end

  teardown do
    if Anthropic::Client.singleton_class.instance_methods(false).include?(:new)
      Anthropic::Client.singleton_class.remove_method(:new)
    end
  end

  test "generates and persists the description for the model" do
    stub_anthropic

    AiModelDescriptionJob.perform_now(model)
    model.reload

    assert_equal "A frontier reasoning model.", model.description
    assert_equal "Reasoning.", model.strengths
  end

  test "swallows a generation error without raising or persisting" do
    stub_anthropic(raises: Anthropic::Errors::Error.new("overloaded"))
    before = model.description

    assert_nothing_raised { AiModelDescriptionJob.perform_now(model) }
    assert_equal before, model.reload.description
  end

  # No client injected and no key stubbed, so AnthropicClient.build hits its
  # real credential guard — exercises the missing-key path end to end.
  test "swallows a missing API key error without raising or persisting" do
    before = model.description

    assert_nothing_raised { AiModelDescriptionJob.perform_now(model) }
    assert_equal before, model.reload.description
  end
end
