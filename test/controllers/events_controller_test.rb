require "test_helper"

class EventsControllerTest < ActionDispatch::IntegrationTest
  PER_PAGE = EventsController::PER_PAGE

  test "renders the market-events timeline" do
    get events_url
    assert_response :success
    assert_select "h1", /Market events/
  end

  test "lists curated market events and model launches" do
    # Dated today so it lands on the first page regardless of how many events
    # the catalog accumulates ahead of it.
    MarketEvent.create!(title: "The DeepSeek moment", event_date: Date.current,
                        kind: "market", status: "published", note: "Markets jolt.")

    get events_url
    assert_response :success
    # A curated market event...
    assert_select ".ev-title", text: /The DeepSeek moment/
    # ...and a model launch (launch titles link to the model).
    assert_select ".ev-title a", text: /Claude Opus 4.8 released/
  end

  test "orders year groups and the events within them newest-first" do
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

  test "never renders price-change rows, even for a model with a tracked reprice" do
    get events_url
    assert_response :success

    # deepseek_v4 has a 75% cut in the fixtures — the exact case that used to
    # surface as a reprice row. Price changes are no longer events.
    assert_select ".ev-item[data-kind=reprice]", count: 0
  end

  test "an old ?kind=reprice link degrades gracefully to the unfiltered timeline" do
    get events_url(kind: "reprice")
    assert_response :success
    # "reprice" isn't a recognized filter anymore, so it behaves like no filter.
    assert_select ".tp-seg a.on[data-kind=all]"
    assert_select ".ev-item[data-kind=launch]", minimum: 1
  end

  test "excludes draft market events" do
    # Dated today: were drafts wrongly included, this would surface on page one.
    MarketEvent.create!(title: "Unpublished draft event", event_date: Date.current,
                        kind: "market", status: "draft")

    get events_url
    assert_response :success
    assert_select ".ev-title", text: /Unpublished draft event/, count: 0
  end

  test "renders a kind filter linking to each server-side view" do
    get events_url
    assert_response :success
    assert_select ".tp-seg a[data-kind=all][href=?]", events_path
    assert_select ".tp-seg a[data-kind=market][href=?]", events_path(kind: "market")
    assert_select ".tp-seg a[data-kind=launch][href=?]", events_path(kind: "launch")
    # No filter active → the "All" tab is the selected one.
    assert_select ".tp-seg a.on[data-kind=all]"
  end

  test "caps the first page and offers a load-more sentinel when more remain" do
    seed_market_events(PER_PAGE + 5)

    get events_url
    assert_response :success
    assert_equal PER_PAGE, css_select(".ev-item").size,
      "the first page should hold exactly PER_PAGE events when more remain"
    assert_select "#ev-sentinel[data-next-url=?]", events_path(page: 2)
  end

  test "a direct page hit renders cumulatively so no-JS paging stays coherent" do
    seed_market_events(PER_PAGE + 5)

    page_one = (get(events_url) && css_select(".ev-item").size)
    page_two = (get(events_url(page: 2)) && css_select(".ev-item").size)
    assert_operator page_two, :>, page_one,
      "page two (HTML) should include page one's events plus the next batch"
  end

  test "a turbo-stream request appends only the requested page" do
    seed_market_events(PER_PAGE + 5)

    get events_url(page: 2), as: :turbo_stream
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", @response.media_type
    assert_select "turbo-stream[action=append][target=ev-timeline]"
    assert_select "turbo-stream[action=replace][target=ev-sentinel]"
    # Only the second page's slice, not a cumulative render — and not empty.
    appended = css_select("turbo-stream[target=ev-timeline] .ev-item").size
    assert_operator appended, :>, 0
    assert_operator appended, :<=, PER_PAGE
  end

  test "the kind filter restricts the timeline server-side" do
    get events_url(kind: "launch")
    assert_response :success
    assert_select ".tp-seg a.on[data-kind=launch]"
    assert_operator css_select(".ev-item[data-kind=launch]").size, :>, 0
    assert_select ".ev-item[data-kind=market]", count: 0
  end

  test "exhausting the timeline renders an end cap instead of a sentinel" do
    get events_url(page: 999)
    assert_response :success
    assert_select ".ev-sentinel-end"
    assert_select "#ev-sentinel[data-next-url]", count: 0
  end

  test "emits a self-canonical link that ignores query params" do
    get events_url(ref: "twitter")
    assert_response :success
    assert_select "link[rel=canonical][href=?]", events_url
  end

  private

  # Publish n market events on distinct, descending recent dates — enough to push
  # the timeline past a single page so the pagination paths have data to exercise.
  def seed_market_events(count)
    count.times do |i|
      MarketEvent.create!(title: "Seeded event #{i}", event_date: Date.current - i,
                          kind: "market", status: "published")
    end
  end
end
