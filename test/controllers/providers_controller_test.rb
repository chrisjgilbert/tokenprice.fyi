require "test_helper"

class ProvidersControllerTest < ActionDispatch::IntegrationTest
  test "shows a provider and its models" do
    get provider_url(providers(:anthropic))
    assert_response :success
    assert_select "h1", "Anthropic"
    assert_select "td", /Claude Opus 4.8/
  end
end
