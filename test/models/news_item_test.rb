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
