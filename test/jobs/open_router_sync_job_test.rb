require "test_helper"

class OpenRouterSyncJobTest < ActiveJob::TestCase
  test "perform runs the model sync" do
    calls = 0
    empty_result = OpenRouter::ModelSync::Result.new(
      created: 0, enriched: 0, repriced: 0, skipped: 0,
      created_records: [], repriced_records: []
    )
    original = OpenRouter::ModelSync.singleton_class.instance_method(:call)
    OpenRouter::ModelSync.define_singleton_method(:call) { |*, **| calls += 1; empty_result }

    begin
      OpenRouterSyncJob.perform_now
    ensure
      OpenRouter::ModelSync.singleton_class.define_method(:call, original)
    end

    assert_equal 1, calls, "expected the job to invoke OpenRouter::ModelSync.call once"
  end

  test "posts Slack payload when sync returns created or repriced records" do
    repriced = OpenRouter::ModelSync::RepricedRecord.new(
      model_name: "Claude Opus 4.8", provider_name: "Anthropic",
      model_slug: "anthropic-claude-opus-4-8",
      old_input: 15.0, old_output: 75.0, old_cached: nil,
      new_input: 12.0, new_output: 60.0, new_cached: nil,
      pct_input_change: -20.0
    )
    result = OpenRouter::ModelSync::Result.new(
      created: 0, enriched: 1, repriced: 1, skipped: 0,
      created_records: [], repriced_records: [ repriced ]
    )

    posted_payloads = []
    original_sync    = OpenRouter::ModelSync.singleton_class.instance_method(:call)
    original_post    = SlackNotifier.singleton_class.instance_method(:post)

    OpenRouter::ModelSync.define_singleton_method(:call) { |*, **| result }
    SlackNotifier.define_singleton_method(:post) { |payload| posted_payloads << payload }

    begin
      OpenRouterSyncJob.perform_now
    ensure
      OpenRouter::ModelSync.singleton_class.define_method(:call, original_sync)
      SlackNotifier.singleton_class.define_method(:post, original_post)
    end

    assert_equal 1, posted_payloads.size, "expected SlackNotifier.post to be called once"
    assert_not_nil posted_payloads.first, "expected a non-nil payload"
  end

  test "does not post to Slack when sync returns no notable changes" do
    result = OpenRouter::ModelSync::Result.new(
      created: 0, enriched: 5, repriced: 0, skipped: 2,
      created_records: [], repriced_records: []
    )

    post_called = false
    original_sync = OpenRouter::ModelSync.singleton_class.instance_method(:call)
    original_post = SlackNotifier.singleton_class.instance_method(:post)

    OpenRouter::ModelSync.define_singleton_method(:call) { |*, **| result }
    SlackNotifier.define_singleton_method(:post) { |_| post_called = true }

    begin
      OpenRouterSyncJob.perform_now
    ensure
      OpenRouter::ModelSync.singleton_class.define_method(:call, original_sync)
      SlackNotifier.singleton_class.define_method(:post, original_post)
    end

    assert_equal false, post_called, "expected no Slack post when nothing notable changed"
  end
end
