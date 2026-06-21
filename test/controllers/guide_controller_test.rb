require "test_helper"

class GuideControllerTest < ActionDispatch::IntegrationTest
  test "index renders the task chooser with the deck H1 and every task linked" do
    get guide_path
    assert_response :success

    assert_select "h1", text: /Your job is a pipeline\. Here's a starting model per step, priced per call\./

    FeaturePattern.all.each do |pattern|
      assert_select "a[href=?]", guide_task_path(pattern.key), text: /#{Regexp.escape(pattern.label)}/
    end
  end

  test "show resolves for a known task and shows its label" do
    get guide_task_path("rag")
    assert_response :success
    assert_select "h1", text: /#{Regexp.escape(FeaturePattern.find("rag").label)}/
  end

  test "show 404s for an unknown task" do
    get "/guide/nonsense"
    assert_response :not_found
  end
end
