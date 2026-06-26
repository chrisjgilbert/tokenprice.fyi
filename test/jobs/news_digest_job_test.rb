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

  # --- Slack block size limits -----------------------------------------------

  # Slack rejects a message ("invalid_blocks", HTTP 400) when a single section
  # block's text exceeds 3000 chars. A digest backlog can blow past that, so the
  # lines must be split across multiple section blocks.
  test "splits long digests across multiple section blocks under Slack's limit" do
    50.times do |i|
      make_item(url: "https://anthropic.com/news/item-#{i}",
                title: "Release #{i} — #{"x" * 80}",
                rationale: "Rationale #{i} — #{"y" * 80}")
    end

    NewsDigestJob.perform_now

    sections = @posted.first[:blocks].select { |b| b[:type] == "section" }
    assert_operator sections.size, :>, 1, "expected the digest to span multiple section blocks"
    sections.each do |block|
      assert_operator block.dig(:text, :text).length, :<=, 3000,
                      "each section block must stay within Slack's 3000-char limit"
    end
  end

  test "truncates a single line that exceeds the section limit" do
    make_item(title: "z" * 4000)

    NewsDigestJob.perform_now

    sections = @posted.first[:blocks].select { |b| b[:type] == "section" }
    sections.each do |block|
      assert_operator block.dig(:text, :text).length, :<=, 3000
    end
    text = sections.map { |b| b.dig(:text, :text) }.join("\n")
    assert_includes text, "…", "an over-long line should be truncated with an ellipsis"
  end

  # Slack also rejects a message with more than 50 blocks. A backlog large
  # enough to need 49+ section blocks must not blow that limit, and the items
  # that don't fit must stay unnotified so the next run picks them up.
  test "caps blocks at Slack's limit and holds the overflow for the next digest" do
    # Each item's line exceeds the per-section budget, so it gets its own
    # section block — 49 items would need 49 sections, one past the budget.
    items = 49.times.map do |i|
      make_item(url: "https://anthropic.com/news/big-#{i}", title: "Big #{i} #{"x" * 3000}")
    end

    NewsDigestJob.perform_now

    blocks = @posted.first[:blocks]
    assert_operator blocks.size, :<=, 50, "Slack rejects messages with more than 50 blocks"

    held_back = items.select { |it| it.reload.notified_at.nil? }
    assert_not_empty held_back, "expected overflow items to remain unnotified for the next run"

    summary = blocks.filter_map { |b| b.dig(:text, :text) }.find { |t| t&.include?("item") }
    assert_includes summary, "more in the next digest"
  end

  # --- notified_at stamping --------------------------------------------------

  test "stamps notified_at on items after successful post" do
    item = make_item
    NewsDigestJob.perform_now
    assert_not_nil item.reload.notified_at
  end

  test "does not stamp notified_at when Slack post raises" do
    item     = make_item
    original = SlackNotifier.singleton_class.instance_method(:post)
    SlackNotifier.define_singleton_method(:post) { |_| raise RuntimeError, "Slack error" }
    begin
      assert_raises(RuntimeError) { NewsDigestJob.perform_now }
    ensure
      SlackNotifier.singleton_class.define_method(:post, original)
    end
    assert_nil item.reload.notified_at
  end

  test "stamps notified_at on unclassified items after successful post" do
    item = make_item(relevant: nil, kind: nil, rationale: nil)
    NewsDigestJob.perform_now
    assert_not_nil item.reload.notified_at
  end
end
