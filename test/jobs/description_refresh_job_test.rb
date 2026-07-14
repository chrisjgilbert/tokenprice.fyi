require "test_helper"

# Ensure the SDK's error base exists for the failure stub even if the gem
# isn't fully loaded in the test environment (mirrors the description job test).
unless defined?(Anthropic::Errors::Error)
  module Anthropic
    module Errors
      class Error < StandardError; end
    end
  end
end

class DescriptionRefreshJobTest < ActiveJob::TestCase
  def stub_anthropic(input: default_input, raises: nil)
    stub_anthropic_key!
    fake = fake_anthropic_tool_client(input: input, raises: raises)
    Anthropic::Client.define_singleton_method(:new) { |**_| fake }
  end

  def default_input
    { description: "Refreshed.", strengths: "Refreshed S.",
      best_for: "Refreshed B.", limitations: "Refreshed L." }
  end

  teardown do
    if Anthropic::Client.singleton_class.instance_methods(false).include?(:new)
      Anthropic::Client.singleton_class.remove_method(:new)
    end
  end

  # A listed (priced) OpenRouter row with a stale write-up.
  def stale_model(generated_at: (AiModel::STALE_AFTER + 1.day).ago, **attrs)
    model = AiModel.create!({
      provider:    providers(:anthropic),
      source:      AiModel::OPENROUTER_SOURCE,
      name:        "Stale #{SecureRandom.hex(4)}",
      status:      "active",
      description: "Old.", strengths: "Old S.", best_for: "Old B.", limitations: "Old L.",
      description_generated_at: generated_at
    }.merge(attrs))
    model.price_points.create!(effective_on: Date.current, input_per_mtok: 1,
                               output_per_mtok: 1, source: "test")
    model
  end

  test "refreshes stale OpenRouter rows" do
    stub_anthropic
    model = stale_model

    DescriptionRefreshJob.perform_now

    assert_equal "Refreshed.", model.reload.description
  end

  test "leaves a fresh row alone" do
    stub_anthropic
    fresh = stale_model(generated_at: 1.day.ago)

    DescriptionRefreshJob.perform_now

    assert_equal "Old.", fresh.reload.description
  end

  # An approved-candidate row is source: manual but its copy is generated (it has
  # a stamp), so it is refreshed like any other generated row.
  test "refreshes generated manual rows (approved candidates)" do
    stub_anthropic
    candidate = stale_model(source: AiModel::MANUAL_SOURCE,
                            generated_at: (AiModel::STALE_AFTER + 1.day).ago)

    DescriptionRefreshJob.perform_now

    assert_equal "Refreshed.", candidate.reload.description
  end

  # A hand-written seed row has no generation stamp; automation must never touch
  # it, even when it's manual and old.
  test "never refreshes hand-written rows (no generation stamp)" do
    stub_anthropic
    hand_written = stale_model(source: AiModel::MANUAL_SOURCE, generated_at: nil)

    DescriptionRefreshJob.perform_now

    assert_equal "Old.", hand_written.reload.description
  end

  test "honours the per-run cap" do
    stub_anthropic
    (DescriptionRefreshJob::REFRESH_PER_RUN + 3).times { stale_model }

    DescriptionRefreshJob.perform_now

    refreshed = AiModel.from_openrouter.where(description: "Refreshed.").count
    assert_equal DescriptionRefreshJob::REFRESH_PER_RUN, refreshed
  end

  test "a generation error is swallowed, not raised" do
    stub_anthropic(raises: Anthropic::Errors::Error.new("overloaded"))
    model = stale_model

    assert_nothing_raised { DescriptionRefreshJob.perform_now }
    assert_equal "Old.", model.reload.description
  end
end
