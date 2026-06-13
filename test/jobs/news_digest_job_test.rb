require "test_helper"

class NewsDigestJobTest < ActiveJob::TestCase
  def make_item(overrides = {})
    NewsItem.create!(
      url:       overrides.fetch(:url,       "https://anthropic.com/news/claude-5"),
      title:     overrides.fetch(:title,     "Introducing Claude 5"),
      source:    overrides.fetch(:source,    "anthropic"),
      kind:      overrides.fetch(:kind,      "release"),
      relevant:  overrides.fetch(:relevant,  true),
      rationale: overrides.fetch(:rationale, "New major model release")
    )
  end

  setup do
    # Silence fixture items so each test starts with a clean pending_digest pool.
    NewsItem.where(notified_at: nil).update_all(notified_at: 1.day.ago)

    @original_post = SlackNotifier.singleton_class.instance_method(:post)
    @posted = []
    posted  = @posted
    SlackNotifier.define_singleton_method(:post) { |payload| posted << payload }
  end

  teardown do
    SlackNotifier.singleton_class.define_method(:post, @original_post)
  end

  # --- early exit ------------------------------------------------------------

  test "does nothing when no pending news items exist" do
    NewsDigestJob.perform_now
    assert_empty @posted
  end

  # --- Slack payload ---------------------------------------------------------

  test "posts to Slack when pending items exist" do
    make_item
    NewsDigestJob.perform_now
    assert_equal 1, @posted.size
  end

  test "payload includes item title and source" do
    make_item(title: "Introducing Claude 5", source: "anthropic",
              url: "https://anthropic.com/news/claude-5")
    NewsDigestJob.perform_now
    text = @posted.first[:blocks].filter_map { |b| b.dig(:text, :text) }.join("\n")
    assert_includes text, "Introducing Claude 5"
    assert_includes text, "anthropic.com/news/claude-5"
    assert_includes text, "(anthropic)"
  end

  test "classified item shows kind and rationale" do
    make_item(kind: "release", rationale: "New major model release")
    NewsDigestJob.perform_now
    text = @posted.first[:blocks].filter_map { |b| b.dig(:text, :text) }.join("\n")
    assert_includes text, "release"
    assert_includes text, "New major model release"
  end

  test "unclassified item shows warning marker" do
    make_item(relevant: nil, kind: nil, rationale: nil)
    NewsDigestJob.perform_now
    text = @posted.first[:blocks].filter_map { |b| b.dig(:text, :text) }.join("\n")
    assert_includes text, "⚠ unclassified"
  end

  # --- notified_at stamping --------------------------------------------------

  test "stamps notified_at on items after successful post" do
    item = make_item
    NewsDigestJob.perform_now
    assert_not_nil item.reload.notified_at
  end

  test "does not stamp notified_at when Slack post raises" do
    item = make_item
    SlackNotifier.define_singleton_method(:post) { |_| raise RuntimeError, "Slack error" }
    assert_raises(RuntimeError) { NewsDigestJob.perform_now }
    assert_nil item.reload.notified_at
  end

  test "already-notified items are not re-posted" do
    make_item(url: "https://anthropic.com/news/already")
      .update!(notified_at: 1.hour.ago)
    NewsDigestJob.perform_now
    assert_empty @posted
  end
end
