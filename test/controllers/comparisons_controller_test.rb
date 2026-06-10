require "test_helper"

class ComparisonsControllerTest < ActionDispatch::IntegrationTest
  test "renders a default comparison with no params" do
    get compare_url
    assert_response :success
    assert_select "form"
  end

  test "compares the two requested models" do
    get compare_url(a: ai_models(:opus).slug, b: ai_models(:deepseek_v4).slug)
    assert_response :success
    assert_select "th", /Claude Opus 4.8/
    assert_select "th", /DeepSeek V4 Pro/
  end
end
