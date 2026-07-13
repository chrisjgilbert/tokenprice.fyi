require "test_helper"

class SitemapsControllerTest < ActionDispatch::IntegrationTest
  test "renders an XML sitemap listing model URLs" do
    get sitemap_url
    assert_response :success
    assert_equal "application/xml", @response.media_type
    assert_includes @response.body, model_url(ai_models(:opus))
    assert_includes @response.body, "<urlset"
  end

  test "the sitemap lists the image-generation tab as its own URL" do
    get sitemap_url
    assert_response :success
    assert_includes @response.body, image_generation_url
  end

  test "the sitemap lists the embeddings tab as its own URL" do
    get sitemap_url
    assert_response :success
    assert_includes @response.body, embeddings_url
  end

  test "the sitemap lists the speech-to-text tab as its own URL" do
    get sitemap_url
    assert_response :success
    assert_includes @response.body, speech_to_text_url
  end

  test "the sitemap lists every category tab URL off the registry" do
    get sitemap_url
    assert_response :success
    ModelCategory.all.each do |category|
      url = send("#{category.path_name}_url")
      assert_includes @response.body, url, "sitemap missing #{category.slug} tab (#{url})"
    end
  end

  test "the sitemap omits the retired trends, guide, and which-model URLs" do
    get sitemap_url
    assert_response :success
    assert_not_includes @response.body, "/trends"
    assert_not_includes @response.body, "/guide"
    assert_not_includes @response.body, "/which-model"
  end

  test "the sitemap no longer advertises the retired news feed" do
    get sitemap_url
    assert_response :success
    assert_not_includes @response.body, "/news"
  end
end
