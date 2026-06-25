require "test_helper"

class EventsControllerTest < ActionDispatch::IntegrationTest
  test "renders the market-events timeline" do
    get events_url
    assert_response :success
    assert_select "h1", /Market events/
  end

  test "lists curated market events and model launches" do
    MarketEvent.create!(title: "The DeepSeek moment", event_date: Date.new(2025, 1, 20),
                        kind: "market", status: "published", note: "Markets jolt.")

    get events_url
    assert_response :success
    # A curated market event...
    assert_select ".ev-title", text: /The DeepSeek moment/
    # ...and a model launch (launch titles link to the model).
    assert_select ".ev-title a", text: /Claude Opus 4.8 released/
  end

  test "orders year groups and the events within them newest-first" do
    MarketEvent.create!(title: "Older milestone", event_date: Date.new(2024, 1, 1),
                        kind: "market", status: "published")
    # A market event mixed in among the 2026 launches, so within-year ordering
    # is exercised across both kinds, not just at year boundaries.
    MarketEvent.create!(title: "Mid-year milestone", event_date: Date.new(2026, 1, 15),
                        kind: "market", status: "published")

    get events_url
    assert_response :success

    years = css_select(".ev-year").map { |el| el.text.strip }
    assert_equal years.sort.reverse, years, "year headers should run newest-first"
    assert_equal "2026", years.first, "the newest fixture launches are in 2026"

    # Every event, across AND within years, must descend by date — this is what
    # proves the intra-year ordering, which the year-header check alone misses.
    dates = css_select(".ev-item time").map { |el| el["datetime"] }
    assert_operator dates.size, :>, 1, "expected several dated events in the timeline"
    assert_equal dates.sort.reverse, dates, "events should render newest-first by date"
  end

  test "excludes draft market events" do
    MarketEvent.create!(title: "Unpublished draft event", event_date: Date.new(2025, 6, 1),
                        kind: "market", status: "draft")

    get events_url
    assert_response :success
    assert_select ".ev-title", text: /Unpublished draft event/, count: 0
  end

  test "renders a kind filter with per-kind counts" do
    get events_url
    assert_response :success
    assert_select ".tp-seg button[data-kind=all]"
    assert_select ".tp-seg button[data-kind=market]"
    assert_select ".tp-seg button[data-kind=launch]"
  end

  test "emits a self-canonical link that ignores query params" do
    get events_url(ref: "twitter")
    assert_response :success
    assert_select "link[rel=canonical][href=?]", events_url
  end

  test "the retired /trends URL redirects permanently to /events" do
    get "/trends"
    assert_response :moved_permanently
    assert_redirected_to "/events"
  end
end
