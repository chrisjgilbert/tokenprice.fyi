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

  test "scopes both pickers to the left model's category" do
    get compare_url(a: "test-priced-image-model")
    assert_response :success
    # Every picker option is an image model; a language model never appears.
    assert_select "li[data-model-name=?]", ai_models(:image_gen).name
    assert_select "li[data-model-name=?]", "Claude Opus 4.8", count: 0
  end

  test "a cross-category b param is ignored, keeping the comparison within one category" do
    get compare_url(a: "test-priced-image-model", b: "claude-opus-4-8")
    assert_response :success
    # Opus is a language model; it must not become the right side.
    assert_select ".sel-btn-name", text: /Claude Opus 4.8/, count: 0
  end

  test "a native-priced comparison shows price headlines, not token I/O rows" do
    get compare_url(a: "test-priced-image-model", b: ai_models(:image_gen).slug)
    assert_response :success
    assert_select ".cmp-row .lbl", text: /Price/
    assert_select ".cmp-cell", text: %r{\$0\.04 / image}
    # No per-token rows for image models.
    assert_select ".cmp-row .lbl", text: %r{Input /1M}, count: 0
  end
end
