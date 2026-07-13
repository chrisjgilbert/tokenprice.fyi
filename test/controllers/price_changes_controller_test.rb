require "test_helper"

class PriceChangesControllerTest < ActionDispatch::IntegrationTest
  test "lists a model that repriced in the last 30 days" do
    provider = Provider.create!(name: "Strip Labs", slug: "strip-labs", accent: "#123456")
    model = provider.ai_models.create!(name: "Stripper One", slug: "stripper-one",
                                       source: AiModel::MANUAL_SOURCE)
    model.price_points.create!(effective_on: Date.current - 5, input_per_mtok: 2, output_per_mtok: 8)
    model.price_points.create!(effective_on: Date.current - 1, input_per_mtok: 3, output_per_mtok: 8)

    get price_changes_url
    assert_response :success
    assert_select "h1", /Recent price changes/
    assert_select "section.changes .c-name", text: /Stripper One/
    assert_select "section.changes .c-leg", /\$2/ # the old input rate
  end

  test "renders an empty state when nothing repriced recently" do
    get price_changes_url
    assert_response :success
    assert_select "section.changes", count: 0
    assert_select ".changes-empty", /No price changes/
  end

  test "links back to the curated events timeline, and is not in the primary nav" do
    get price_changes_url
    assert_response :success
    assert_select ".changes-subtitle a[href=?]", events_path
    assert_select "nav.tp-nav a[href='/changes']", count: 0
  end

  test "sets a conditional-GET etag off the catalog freshness" do
    get price_changes_url
    assert_response :success
    assert response.etag.present?
  end
end
