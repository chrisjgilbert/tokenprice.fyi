require "test_helper"

class NewsControllerTest < ActionDispatch::IntegrationTest
  PER_PAGE = NewsController::PER_PAGE

  test "renders the news feed" do
    get news_url
    assert_response :success
    assert_select "h1", /News/
  end

  test "shows the recent price changes strip for a recent repricing" do
    provider = Provider.create!(name: "Strip Labs", slug: "strip-labs", accent: "#123456")
    model = provider.ai_models.create!(name: "Stripper One", slug: "stripper-one",
                                       tier: "mid", source: AiModel::MANUAL_SOURCE)
    model.price_points.create!(effective_on: Date.current - 5, input_per_mtok: 2, output_per_mtok: 8)
    model.price_points.create!(effective_on: Date.current - 1, input_per_mtok: 3, output_per_mtok: 8)

    get news_url
    assert_response :success
    assert_select "section.changes .c-name", text: /Stripper One/
    assert_select "section.changes .c-leg", /\$2/  # old input rate on the strip
  end

  test "lists relevant items with their rationale and kind badge" do
    get news_url
    assert_response :success
    assert_select ".n-title", text: /Introducing Claude Haiku 4.5/
    assert_select ".n-rat",   text: /New Claude model release/
    assert_select ".tp-badge.tp-kind-release"
  end

  test "excludes irrelevant and unclassified items" do
    get news_url
    assert_response :success
    assert_select ".n-title", text: /Meta company update/, count: 0
    assert_select ".n-title", text: /DeepSeek blog post/,   count: 0
  end

  test "groups items under a day header" do
    get news_url
    assert_response :success
    assert_select ".n-day-head", text: /Jun 1, 2026/
  end

  test "links an item that became a published event to the events timeline" do
    event = MarketEvent.create!(title: "Haiku shifts the small tier", event_date: Date.current,
                                kind: "market", status: "published")
    news_items(:anthropic_haiku_release).update!(market_event: event)

    get news_url
    assert_response :success
    assert_select "a.n-linked[href=?]", events_path
  end

  test "does not link items whose event is still a draft" do
    event = MarketEvent.create!(title: "Draft only", event_date: Date.current,
                                kind: "market", status: "draft")
    news_items(:anthropic_haiku_release).update!(market_event: event)

    get news_url
    assert_response :success
    assert_select "a.n-linked", count: 0
  end

  test "paginates with a cumulative Load more link" do
    (PER_PAGE + 1).times do |i|
      NewsItem.create!(url: "https://example.com/n#{i}", title: "Feed item #{i}",
                       source: "hn", relevant: true, kind: "price",
                       published_at: (i + 1).minutes.ago)
    end

    get news_url
    assert_response :success
    assert_select "a.n-more[href=?]", news_path(page: 2)

    get news_url(page: 2)
    assert_response :success
    assert_select "a.n-more", count: 0
  end

  test "supports conditional GET on the news table's freshness" do
    get news_url
    assert_response :success
    etag = response.headers["ETag"]

    get news_url, headers: { "If-None-Match" => etag }
    assert_response :not_modified
  end
end
