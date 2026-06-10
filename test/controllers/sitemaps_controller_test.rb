require "test_helper"

class SitemapsControllerTest < ActionDispatch::IntegrationTest
  test "renders an XML sitemap listing model URLs" do
    get sitemap_url
    assert_response :success
    assert_equal "application/xml", @response.media_type
    assert_includes @response.body, model_url(ai_models(:opus))
    assert_includes @response.body, "<urlset"
  end
end
