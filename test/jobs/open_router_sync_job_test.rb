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
      pct_blended_change: -20.0
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

  test "does not post to Slack when sync returns no notable changes and no pending news items" do
    result = OpenRouter::ModelSync::Result.new(
      created: 0, enriched: 5, repriced: 0, skipped: 2,
      created_records: [], repriced_records: []
    )

    post_called = false
    original_sync   = OpenRouter::ModelSync.singleton_class.instance_method(:call)
    original_post   = SlackNotifier.singleton_class.instance_method(:post)
    original_pending = NewsItem.singleton_class.instance_method(:pending_digest)

    OpenRouter::ModelSync.define_singleton_method(:call) { |*, **| result }
    SlackNotifier.define_singleton_method(:post) { |_| post_called = true }
    # Override pending_digest to return an empty scope so fixtures don't interfere.
    NewsItem.define_singleton_method(:pending_digest) { NewsItem.none }

    begin
      OpenRouterSyncJob.perform_now
    ensure
      OpenRouter::ModelSync.singleton_class.define_method(:call, original_sync)
      SlackNotifier.singleton_class.define_method(:post, original_post)
      NewsItem.singleton_class.define_method(:pending_digest, original_pending)
    end

    assert_equal false, post_called, "expected no Slack post when nothing notable changed"
  end

  # --- news items integration ------------------------------------------------

  test "pending news items are passed to SyncDigest and appear in the payload" do
    # Create a pending (unnotified, relevant) news item in the DB.
    pending_item = NewsItem.create!(
      url:       "https://anthropic.com/news/claude-5",
      title:     "Introducing Claude 5",
      source:    "anthropic",
      kind:      "release",
      relevant:  true,
      rationale: "New major model release"
    )

    empty_result = OpenRouter::ModelSync::Result.new(
      created: 0, enriched: 0, repriced: 0, skipped: 0,
      created_records: [], repriced_records: []
    )

    captured_news_items = nil
    original_sync = OpenRouter::ModelSync.singleton_class.instance_method(:call)
    original_post = SlackNotifier.singleton_class.instance_method(:post)
    original_new  = OpenRouter::SyncDigest.singleton_class.instance_method(:new)

    OpenRouter::ModelSync.define_singleton_method(:call) { |*, **| empty_result }
    SlackNotifier.define_singleton_method(:post) { |_| }
    OpenRouter::SyncDigest.define_singleton_method(:new) do |result, **kwargs|
      captured_news_items = kwargs[:news_items]
      original_new.bind(OpenRouter::SyncDigest).call(result, **kwargs)
    end

    begin
      OpenRouterSyncJob.perform_now
    ensure
      OpenRouter::ModelSync.singleton_class.define_method(:call, original_sync)
      SlackNotifier.singleton_class.define_method(:post, original_post)
      OpenRouter::SyncDigest.singleton_class.define_method(:new, original_new)
    end

    assert_not_nil captured_news_items, "expected news_items to be passed to SyncDigest"
    pending_ids = captured_news_items.map(&:id)
    assert_includes pending_ids, pending_item.id,
      "expected the created pending item to be in the SyncDigest news_items"
  end

  test "notified_at is set on pending items after successful Slack post" do
    pending_item = NewsItem.create!(
      url:       "https://anthropic.com/news/claude-5",
      title:     "Introducing Claude 5",
      source:    "anthropic",
      kind:      "release",
      relevant:  true,
      rationale: "New major model release"
    )

    empty_result = OpenRouter::ModelSync::Result.new(
      created: 0, enriched: 0, repriced: 0, skipped: 0,
      created_records: [], repriced_records: []
    )

    original_sync = OpenRouter::ModelSync.singleton_class.instance_method(:call)
    original_post = SlackNotifier.singleton_class.instance_method(:post)

    OpenRouter::ModelSync.define_singleton_method(:call) { |*, **| empty_result }
    SlackNotifier.define_singleton_method(:post) { |_| }

    begin
      OpenRouterSyncJob.perform_now
    ensure
      OpenRouter::ModelSync.singleton_class.define_method(:call, original_sync)
      SlackNotifier.singleton_class.define_method(:post, original_post)
    end

    pending_item.reload
    assert_not_nil pending_item.notified_at, "expected notified_at to be set after successful post"
  end

  test "items are NOT marked notified when Slack post raises" do
    pending_item = NewsItem.create!(
      url:       "https://anthropic.com/news/claude-5",
      title:     "Introducing Claude 5",
      source:    "anthropic",
      kind:      "release",
      relevant:  true,
      rationale: "New major model release"
    )

    empty_result = OpenRouter::ModelSync::Result.new(
      created: 0, enriched: 0, repriced: 0, skipped: 0,
      created_records: [], repriced_records: []
    )

    original_sync = OpenRouter::ModelSync.singleton_class.instance_method(:call)
    original_post = SlackNotifier.singleton_class.instance_method(:post)

    OpenRouter::ModelSync.define_singleton_method(:call) { |*, **| empty_result }
    SlackNotifier.define_singleton_method(:post) { |_| raise RuntimeError, "Slack error" }

    begin
      assert_raises(RuntimeError) { OpenRouterSyncJob.perform_now }
    ensure
      OpenRouter::ModelSync.singleton_class.define_method(:call, original_sync)
      SlackNotifier.singleton_class.define_method(:post, original_post)
    end

    pending_item.reload
    assert_nil pending_item.notified_at, "expected notified_at to remain nil when Slack post fails"
  end
end
