require "application_system_test_case"

# The Guide is the browse-by-task model picker: the homepage CTA leads to a task
# chooser, and each task opens a per-step pipeline with starting models and
# per-call cost estimates. This walks that path the way a visitor finds a model
# for their job.
class GuideNavigationTest < ApplicationSystemTestCase
  test "the homepage CTA leads into the guide" do
    visit root_path

    click_on "Find a model for your task"

    assert_current_path guide_path
    assert_selector "h1", text: "Starting models"
    assert_link "RAG support bot"
  end

  test "choosing a task opens its pipeline with per-call costs" do
    visit guide_path

    click_on "RAG support bot"

    assert_current_path guide_task_path("rag")
    assert_selector "h1", text: "RAG support bot"
    # The RAG steps resolve their starting options against the fixture catalog,
    # so a concrete per-call dollar estimate renders rather than a fallback.
    assert_text "per call"
    assert_text "Guide Haiku Fixture"
  end
end
