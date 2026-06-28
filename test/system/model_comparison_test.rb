require "application_system_test_case"

# The Compare page pits two models side by side. Each side has a popover model
# picker — open it, search, pick — and a swap button. Every selection rewrites
# the ?a=&b= query and re-renders the comparison via a Turbo visit. These
# journeys drive that compare Stimulus controller through the browser.
class ModelComparisonTest < ApplicationSystemTestCase
  test "picking a model from the popover updates the comparison" do
    visit compare_path(a: "claude-opus-4-8", b: "deepseek-v4-pro")

    assert_selector ".sel-btn-name", text: "Claude Opus 4.8"
    assert_selector ".sel-btn-name", text: "DeepSeek V4 Pro"

    # Open side A's picker, narrow it, and choose a different model.
    find('[data-compare-target="btnA"]').click
    within '[data-compare-target="popA"]' do
      fill_in_search "Guide Haiku"
      click_on "Guide Haiku Fixture"
    end

    assert_selector ".sel-btn-name", text: "Guide Haiku Fixture"
    assert_includes current_url, "a=claude-haiku-4-5"
    assert_no_selector ".sel-btn-name", text: "Claude Opus 4.8"
  end

  test "the search box filters the model list inside the popover" do
    visit compare_path(a: "claude-opus-4-8", b: "deepseek-v4-pro")

    find('[data-compare-target="btnB"]').click
    within '[data-compare-target="popB"]' do
      assert_selector "[data-model-name]", text: "Lopri Mid", visible: true
      fill_in_search "haiku"

      assert_selector "[data-model-name]", text: "Guide Haiku Fixture", visible: true
      assert_no_selector "[data-model-name]", text: "Lopri Mid", visible: true
    end
  end

  test "the swap button exchanges the two sides" do
    visit compare_path(a: "claude-opus-4-8", b: "deepseek-v4-pro")

    find('[data-compare-target="swapBtn"]').click

    # Wait for the Turbo visit to land (a retrying matcher) before reading the
    # URL: A becomes DeepSeek, B becomes Opus, and the query reflects the swap.
    within '[data-compare-target="btnA"]' do
      assert_text "DeepSeek V4 Pro"
    end
    assert_includes current_url, "a=deepseek-v4-pro"
    assert_includes current_url, "b=claude-opus-4-8"
  end

  private

  # The popover's search input has no label, so target it by its placeholder.
  def fill_in_search(text)
    find("input[placeholder='Search models…']").set(text)
  end
end
