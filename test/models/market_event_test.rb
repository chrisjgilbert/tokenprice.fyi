require "test_helper"

class MarketEventTest < ActiveSupport::TestCase
  def valid_attrs
    { title: "GPT-4 Turbo: 3× cheaper", event_date: Date.new(2023, 11, 6),
      kind: "market", status: "published" }
  end

  # --- validations -----------------------------------------------------------

  test "valid with required attributes" do
    assert MarketEvent.new(valid_attrs).valid?
  end

  test "invalid without title" do
    assert_not MarketEvent.new(valid_attrs.merge(title: nil)).valid?
  end

  test "invalid without event_date" do
    assert_not MarketEvent.new(valid_attrs.merge(event_date: nil)).valid?
  end

  test "invalid with unknown status" do
    assert_not MarketEvent.new(valid_attrs.merge(status: "pending")).valid?
  end

  test "invalid with unknown kind" do
    assert_not MarketEvent.new(valid_attrs.merge(kind: "launch")).valid?
  end

  test "valid as draft" do
    assert MarketEvent.new(valid_attrs.merge(status: "draft")).valid?
  end

  # --- scopes ----------------------------------------------------------------

  test "published scope returns only published events" do
    pub   = MarketEvent.create!(valid_attrs)
    draft = MarketEvent.create!(valid_attrs.merge(title: "Draft event", status: "draft",
                                                   event_date: Date.new(2024, 1, 1)))

    ids = MarketEvent.published.pluck(:id)
    assert_includes ids, pub.id
    assert_not_includes ids, draft.id
  end

  test "drafts scope returns only draft events" do
    pub   = MarketEvent.create!(valid_attrs)
    draft = MarketEvent.create!(valid_attrs.merge(title: "Draft event", status: "draft",
                                                   event_date: Date.new(2024, 1, 1)))

    ids = MarketEvent.drafts.pluck(:id)
    assert_includes ids, draft.id
    assert_not_includes ids, pub.id
  end

  test "listed scope returns published events in chronological order" do
    e2 = MarketEvent.create!(valid_attrs.merge(event_date: Date.new(2024, 3, 1)))
    e1 = MarketEvent.create!(valid_attrs.merge(event_date: Date.new(2024, 1, 1),
                                                title: "Earlier event"))
    _draft = MarketEvent.create!(valid_attrs.merge(title: "Draft", status: "draft",
                                                    event_date: Date.new(2024, 2, 1)))

    listed = MarketEvent.listed
    listed_ids = listed.map(&:id)
    assert_includes listed_ids, e1.id
    assert_includes listed_ids, e2.id
    assert_not_includes listed_ids, _draft.id
    assert listed_ids.index(e1.id) < listed_ids.index(e2.id), "expected chronological order"
  end

  # --- associations ----------------------------------------------------------

  test "news_items association nullifies market_event_id on destroy" do
    event = MarketEvent.create!(valid_attrs)
    item  = NewsItem.create!(url: "https://example.com/test", title: "Test item",
                              source: "hn", market_event_id: event.id)

    event.destroy
    assert_nil item.reload.market_event_id
  end
end
