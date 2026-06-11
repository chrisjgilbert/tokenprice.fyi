require "test_helper"

class MapControllerTest < ActionDispatch::IntegrationTest
  test "renders the world map grouped by country" do
    get map_url
    assert_response :success

    # Fixtures place Anthropic in the US and DeepSeek in China.
    assert_select "svg.map-svg"
    assert_select ".map-country-card", minimum: 2
    assert_select "h1", /geopolitics/i
    assert_match "United States", response.body
    assert_match "China", response.body
    assert_match "🇺🇸", response.body
  end

  test "each country shows a median price" do
    get map_url
    assert_response :success
    assert_select ".map-cc-metric-label", text: "median I/O /1M", minimum: 2
    # the hover payload the Stimulus controller reads carries it too
    assert_select "[data-map-countries-value]"
  end

  test "countries deep-link into the filtered price table" do
    get map_url
    assert_response :success
    # Anthropic is the US fixture provider — the US shape links to it.
    assert_select "a[data-code=?][href*=?]", "US", "providers%5B%5D=anthropic"
    assert_select "a.map-cc-view[href*=?]", "providers%5B%5D="
  end

  test "lists providers without a country separately" do
    Provider.create!(name: "Stateless Labs")
    get map_url
    assert_response :success
    assert_match "Stateless Labs", response.body
  end
end
