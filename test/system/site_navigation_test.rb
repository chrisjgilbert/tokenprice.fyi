require "application_system_test_case"

# The chrome that wraps every page: the desktop "Learn" dropdown and the mobile
# slide-down drawer. Both are Stimulus-driven and only appear at their own
# breakpoint, so each test sizes the window for the layout it exercises.
class SiteNavigationTest < ApplicationSystemTestCase
  test "the Learn dropdown opens and navigates to an explainer" do
    visit root_path

    find("button.tp-nav-trigger", text: "Learn").click
    assert_selector ".tp-nav-group.open"

    within ".tp-nav-menu" do
      click_on "Reasoning tokens"
    end

    assert_current_path learn_reasoning_path
  end

  test "the mobile drawer opens and navigates" do
    resize_to_mobile
    visit root_path

    # The inline desktop links are hidden at this width; open the drawer.
    find("button.tp-nav-toggle").click

    within ".tp-m-panel" do
      click_on "News"
    end

    assert_current_path news_path
    assert_selector "h1.news-h1"
  end
end
