require "test_helper"

class Admin::MarketEventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_admin
    @published = MarketEvent.create!(
      title: "GPT-4 cuts 50%", event_date: Date.new(2024, 5, 1),
      kind: "market", status: "published"
    )
    @draft = MarketEvent.create!(
      title: "Draft event", event_date: Date.new(2024, 6, 1),
      kind: "market", status: "draft", source: "curation",
      source_url: "https://techcrunch.com/ai"
    )
  end

  # --- index -----------------------------------------------------------------

  test "GET index renders both sections" do
    get admin_market_events_path
    assert_response :success
    assert_match @published.title, response.body
    assert_match @draft.title, response.body
  end

  # --- new / create ----------------------------------------------------------

  test "GET new renders form" do
    get new_admin_market_event_path
    assert_response :success
  end

  test "POST create with valid params redirects" do
    assert_difference "MarketEvent.count" do
      post admin_market_events_path, params: {
        market_event: { title: "New event", event_date: "2024-07-01",
                        kind: "market", status: "published", note: "A note." }
      }
    end
    assert_redirected_to admin_market_events_path
  end

  test "POST create with invalid params re-renders form" do
    assert_no_difference "MarketEvent.count" do
      post admin_market_events_path, params: {
        market_event: { title: "", event_date: "2024-07-01", kind: "market", status: "published" }
      }
    end
    assert_response :unprocessable_entity
  end

  # --- edit / update ---------------------------------------------------------

  test "GET edit renders form with draft banner for draft events" do
    get edit_admin_market_event_path(@draft)
    assert_response :success
    assert_match "This is a draft", response.body
  end

  test "GET edit renders form without draft banner for published events" do
    get edit_admin_market_event_path(@published)
    assert_response :success
    assert_no_match "This is a draft", response.body
  end

  test "PATCH update with valid params redirects" do
    patch admin_market_event_path(@published), params: {
      market_event: { title: "Updated title", event_date: @published.event_date,
                      kind: "market", status: "published" }
    }
    assert_redirected_to admin_market_events_path
    assert_equal "Updated title", @published.reload.title
  end

  # --- publish ---------------------------------------------------------------

  test "PATCH publish flips status to published" do
    patch publish_admin_market_event_path(@draft)
    assert_redirected_to admin_market_events_path
    assert_equal "published", @draft.reload.status
  end

  # --- destroy ---------------------------------------------------------------

  test "DELETE destroy removes the event" do
    assert_difference "MarketEvent.count", -1 do
      delete admin_market_event_path(@draft)
    end
    assert_redirected_to admin_market_events_path
  end

  test "DELETE destroy nullifies market_event_id on linked news items" do
    item = NewsItem.create!(url: "https://example.com/x", title: "Test",
                             source: "hn", market_event_id: @draft.id)
    delete admin_market_event_path(@draft)
    assert_nil item.reload.market_event_id
  end

  test "DELETE destroy marks linked news items as not relevant" do
    item = NewsItem.create!(url: "https://example.com/y", title: "Test2",
                             source: "hn", market_event_id: @draft.id, relevant: true)
    delete admin_market_event_path(@draft)
    assert_equal false, item.reload.relevant
  end

  # --- auth guard ------------------------------------------------------------

  test "unauthenticated request redirects to login" do
    delete admin_logout_path, headers: { "X-CSRF-Token" => "any" }
    get admin_market_events_path
    assert_redirected_to admin_login_path
  end
end
