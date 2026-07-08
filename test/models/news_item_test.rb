require "test_helper"

class NewsItemTest < ActiveSupport::TestCase
  # pending_digest scope —————————————————————————————————————————————————

  test "pending_digest includes relevant=true items with notified_at nil" do
    item = news_items(:anthropic_haiku_release)
    assert item.relevant
    assert_nil item.notified_at
    assert_includes NewsItem.pending_digest, item
  end

  test "pending_digest excludes relevant=false items" do
    item = news_items(:irrelevant_item)
    assert_equal false, item.relevant
    refute_includes NewsItem.pending_digest, item
  end

  test "pending_digest includes unclassified (relevant=nil) items with notified_at nil" do
    item = news_items(:unclassified_item)
    assert_nil item.relevant
    assert_nil item.notified_at
    assert_includes NewsItem.pending_digest, item
  end

  test "pending_digest excludes items with notified_at set" do
    item = news_items(:notified_item)
    assert_not_nil item.notified_at
    refute_includes NewsItem.pending_digest, item
  end

  # awaiting_curation scope ——————————————————————————————————————————————

  test "awaiting_curation includes relevant, unattached, uncurated items" do
    item = NewsItem.create!(url: "https://example.com/cur1", title: "Curatable",
                            source: "hn", relevant: true)
    assert_includes NewsItem.awaiting_curation, item
  end

  test "awaiting_curation excludes items already curated" do
    item = NewsItem.create!(url: "https://example.com/cur2", title: "Already curated",
                            source: "hn", relevant: true, curated_at: Time.current)
    refute_includes NewsItem.awaiting_curation, item
  end

  test "awaiting_curation excludes items attached to an event" do
    event = MarketEvent.create!(title: "Evt", event_date: Date.current, kind: "market", status: "draft")
    item  = NewsItem.create!(url: "https://example.com/cur3", title: "Attached",
                             source: "hn", relevant: true, market_event_id: event.id)
    refute_includes NewsItem.awaiting_curation, item
  end

  test "awaiting_curation excludes irrelevant items" do
    item = NewsItem.create!(url: "https://example.com/cur4", title: "Irrelevant",
                            source: "hn", relevant: false)
    refute_includes NewsItem.awaiting_curation, item
  end

  # feed scope ———————————————————————————————————————————————————————————

  test "feed includes relevant, dated items" do
    item = news_items(:anthropic_haiku_release)
    assert item.relevant
    assert_not_nil item.published_at
    assert_includes NewsItem.feed, item
  end

  test "feed includes relevant items even once notified" do
    item = news_items(:notified_item)
    assert item.relevant
    assert_not_nil item.notified_at
    assert_includes NewsItem.feed, item
  end

  test "feed excludes irrelevant items" do
    refute_includes NewsItem.feed, news_items(:irrelevant_item)
  end

  test "feed excludes unclassified (relevant=nil) items" do
    refute_includes NewsItem.feed, news_items(:unclassified_item)
  end

  test "feed excludes relevant items with no publish date" do
    item = NewsItem.create!(url: "https://example.com/undated", title: "Undated",
                            source: "hn", relevant: true, published_at: nil)
    refute_includes NewsItem.feed, item
  end

  test "feed orders newest first by published_at" do
    dates = NewsItem.feed.map(&:published_at)
    assert_equal dates.sort.reverse, dates
  end

  # validations ——————————————————————————————————————————————————————————

  test "valid with url, title, and source" do
    item = NewsItem.new(url: "https://example.com/post", title: "Example Post", source: "example")
    assert item.valid?
  end

  test "invalid without url" do
    item = NewsItem.new(title: "Example Post", source: "example")
    assert_not item.valid?
    assert_includes item.errors[:url], "can't be blank"
  end

  test "invalid without title" do
    item = NewsItem.new(url: "https://example.com/post", source: "example")
    assert_not item.valid?
    assert_includes item.errors[:title], "can't be blank"
  end

  test "invalid without source" do
    item = NewsItem.new(url: "https://example.com/post", title: "Example Post")
    assert_not item.valid?
    assert_includes item.errors[:source], "can't be blank"
  end
end
