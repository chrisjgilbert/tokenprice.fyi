require "test_helper"

class SitemapsControllerTest < ActionDispatch::IntegrationTest
  test "renders an XML sitemap listing model URLs" do
    get sitemap_url
    assert_response :success
    assert_equal "application/xml", @response.media_type
    assert_includes @response.body, model_url(ai_models(:opus))
    assert_includes @response.body, "<urlset"
  end

  test "the sitemap advertises the guide and its task pages, not which-model" do
    get sitemap_url
    assert_response :success
    assert_includes @response.body, guide_url
    assert_includes @response.body, guide_task_url(FeaturePattern.all.first.key)
    assert_not_includes @response.body, "/which-model"
  end

  test "the sitemap includes the learn anatomy explainer" do
    get sitemap_url
    assert_response :success
    assert_includes @response.body, learn_anatomy_url
  end
end
