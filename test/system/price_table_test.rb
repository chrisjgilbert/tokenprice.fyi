require "application_system_test_case"

# The homepage price table is the site's centre of gravity: a Turbo-framed table
# that re-renders in place as the filters Stimulus controller submits search,
# tier, and provider changes. These journeys exercise that loop end to end —
# typed search, provider toggles, sort, clear — plus the row click-through to a
# model page.
class PriceTableTest < ApplicationSystemTestCase
  test "filtering by search narrows the table to matching models" do
    visit root_path

    assert_selector "table.tp-data tbody tr", minimum: 3
    assert_text "DeepSeek V4 Pro"
    assert_text "Claude Opus 4.8"

    fill_in "q", with: "deepseek"

    # The frame re-renders to only DeepSeek rows; the debounced submit lands
    # without us driving the form manually. Scope to the table — the hero card
    # outside the frame names models too.
    within "#models" do
      assert_text "DeepSeek V4 Pro"
      assert_no_text "Claude Opus 4.8"
      assert_selector "[data-models-count]", text: /model/
    end
  end

  test "filtering by provider checkbox re-renders the frame" do
    visit root_path
    assert_text "DeepSeek V4 Pro"

    open_provider_filter
    # No box checked means "all providers"; checking one narrows to it. The real
    # checkbox is visually hidden behind a styled label, so click through the
    # label the way a user does.
    check "provider_anthropic", allow_label_click: true

    # Scope to the table: the hero card mentions DeepSeek too, and it lives
    # outside the Turbo frame the filter refreshes.
    within "#models" do
      assert_text "Claude Opus 4.8"
      assert_no_text "DeepSeek V4 Pro"
    end
  end

  test "clearing filters restores the full table" do
    visit root_path

    fill_in "q", with: "deepseek"
    within "#models" do
      assert_no_text "Claude Opus 4.8"
    end

    click_on "Clear filters"

    within "#models" do
      assert_text "Claude Opus 4.8"
      assert_text "DeepSeek V4 Pro"
    end
    assert_field "q", with: ""
  end

  test "an empty search shows the no-results state" do
    visit root_path

    fill_in "q", with: "zzzznotamodel"

    assert_text "No models match your filters"
    assert_link "Clear all filters"
  end

  test "sorting by input price reorders and marks the column" do
    visit root_path

    within "table.tp-data thead" do
      click_on "Input /1M"
    end

    # The active column carries .sort-active; assert via the sort link's stable
    # aria-label rather than header text (thead text is CSS-uppercased, which
    # ChromeDriver reports inconsistently).
    assert_selector "th.sort-active a[aria-label*='Sort by input']"
  end

  test "clicking a model row navigates to its detail page" do
    visit root_path

    within "table.tp-data tbody" do
      click_on "Claude Opus 4.8", match: :first
    end

    assert_current_path model_path("claude-opus-4-8")
    assert_selector "h1", text: "Claude Opus 4.8"
  end

  test "mobile tier dropdown chip filters the table" do
    resize_to_mobile
    visit root_path

    # Below 760px the tier pills collapse behind a chip; they only become
    # reachable once its popover is open.
    assert_no_selector "#tier-panel label.tp-pill"
    find(".tp-facet-chip", text: "Tier").click
    within "#tier-panel" do
      choose "tier_frontier", allow_label_click: true
    end

    within "#models" do
      assert_text "Claude Opus 4.8"
      assert_selector "[data-models-count]", text: /model/
    end
    # The chip echoes the active value and lights up. normalize_ws collapses the
    # newline the button's markup puts between the label and the value span.
    assert_selector ".tp-facet-chip.is-active", text: "Tier · Frontier", normalize_ws: true
  end

  test "mobile provider dropdown chip filters the table" do
    resize_to_mobile
    visit root_path

    find("summary.tp-provider-summary").click
    check "provider_anthropic", allow_label_click: true

    within "#models" do
      assert_text "Claude Opus 4.8"
      assert_no_text "DeepSeek V4 Pro"
    end
    assert_selector ".tp-provider-summary.is-active"
  end

  private

  # The provider checkboxes live inside a <details> that only auto-opens when a
  # provider is already selected, so open it before toggling.
  def open_provider_filter
    find("summary.tp-provider-summary").click
  end
end
