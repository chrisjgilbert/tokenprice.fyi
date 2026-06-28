require "application_system_test_case"

# Browsing the read pages the way a visitor does: a model's detail page with its
# price-history chart, a provider page and its model list, and the market-events
# timeline with its kind filter. These confirm the pages render and link up in a
# real browser, including the SVG chart the price-chart controller enhances.
class ContentBrowsingTest < ApplicationSystemTestCase
  test "a model detail page shows its price history chart and snapshots" do
    visit model_path("deepseek-v4-pro")

    assert_selector "h1", text: "DeepSeek V4 Pro"
    assert_selector "h2", text: "Price history"
    # The chart renders server-side as SVG (the Stimulus controller only adds the
    # crosshair on top), so it's present without any interaction.
    assert_selector "svg[data-price-chart-target='svg']"
    assert_selector "h2", text: "Snapshots"
    # Two price points (launch + the 75% cut) means a price-change summary.
    assert_text "75.0%"
  end

  test "a provider page lists its models and links through to one" do
    visit provider_path("deepseek")

    assert_selector "h1", text: "DeepSeek"
    assert_text "DeepSeek V4 Pro"

    click_on "DeepSeek V4 Pro", match: :first

    assert_current_path model_path("deepseek-v4-pro")
    assert_selector "h1", text: "DeepSeek V4 Pro"
  end

  test "the events timeline renders and filters by kind" do
    visit events_path

    assert_selector "h1", text: "Market events"
    assert_selector "#ev-timeline"

    click_on "Price changes"

    assert_current_path events_path(kind: "reprice")
    assert_text "DeepSeek V4 Pro"
  end
end
