require "test_helper"

class ComparisonsControllerTest < ActionDispatch::IntegrationTest
  test "renders a default comparison with no params" do
    get compare_url
    assert_response :success
    assert_select "h1", /Compare two models/
  end

  test "canonicalizes every param permutation to the param-free compare URL" do
    get compare_url(a: ai_models(:opus).slug, b: ai_models(:deepseek_v4).slug)
    assert_response :success
    assert_select "link[rel=canonical][href=?]", compare_url
  end

  test "compares the two requested models" do
    get compare_url(a: ai_models(:opus).slug, b: ai_models(:deepseek_v4).slug)
    assert_response :success
    assert_select ".sel-btn-name", /Claude Opus 4.8/
    assert_select ".sel-btn-name", /DeepSeek V4 Pro/
    assert_select ".cmp-table"
  end

  test "the model picker shows a directory row's price as 'not yet tracked', never '— in'" do
    get compare_url
    assert_response :success
    # The price-less image-gen row is listed, so it appears in the picker.
    forge = css_select("li[data-model-name='Pixel Forge 1'] .cmp-pop-item-price").first
    assert forge, "expected the directory row in the compare picker"
    assert_equal "Not yet tracked", forge.text.strip
  end
end
