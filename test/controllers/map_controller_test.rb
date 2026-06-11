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

  test "lists providers without a country separately" do
    Provider.create!(name: "Stateless Labs")
    get map_url
    assert_response :success
    assert_match "Stateless Labs", response.body
  end
end
