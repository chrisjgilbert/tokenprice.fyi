require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "status_badge renders nothing for active models" do
    assert_nil status_badge("active")
  end

  test "status_badge tags suspended models with the suspended class" do
    badge = status_badge("suspended")
    assert_includes badge, "tp-status-suspended"
    assert_includes badge, "suspended"
  end

  test "status_badge tags legacy and retired models" do
    assert_includes status_badge("legacy"), "tp-status-legacy"
    assert_includes status_badge("retired"), "tp-status-retired"
  end

  test "usd keeps full precision for raw-USD dimensions when asked" do
    # Per-1M rates use the default 4 dp; a small per-image/per-request fee would
    # truncate there, so those callers pass decimals: 6.
    assert_equal "$0.0015", usd(0.00153)
    assert_equal "$0.00153", usd(0.00153, decimals: 6)
    assert_equal "$0.000125", usd_plain(0.000125, decimals: 6)
  end

  test "modality_badge stays suppressed for a cased text-only signature" do
    model = AiModel.new(input_modalities: %w[TEXT], output_modalities: %w[Text])
    assert_nil modality_badge(model)
  end

  test "data_updated_tag shows a specific date and carries the precise instant" do
    stamp = Time.utc(2026, 6, 27, 9, 30, 0)
    html = data_updated_tag(stamp)
    assert_includes html, "Data updated Jun 27, 2026"
    assert_select Nokogiri::HTML.fragment(html), "time[datetime=?]", stamp.iso8601
  end

  test "data_updated_tag renders nothing without a timestamp" do
    assert_nil data_updated_tag(nil)
  end

  test "report_problem_link builds a mailto with a prefilled subject and body" do
    html = report_problem_link(subject: "Issue: X", body: "line one\nline two")
    assert_match %r{href="mailto:chris@chrisgilbert\.dev}, html
    assert_includes html, "subject=Issue%3A%20X"
    assert_includes html, "body=line%20one%0Aline%20two"
    assert_includes html, "Report a problem"
  end

  test "modality_badge names the class for a multimodal model and is nil for text" do
    multimodal = AiModel.new(input_modalities: %w[text image], output_modalities: %w[text])
    assert_includes modality_badge(multimodal), "Multimodal"
    assert_nil modality_badge(AiModel.new(input_modalities: %w[text], output_modalities: %w[text]))
  end

  test "io_price renders the per-token I/O pill for a priced model" do
    pill = io_price(ai_models(:opus))
    assert_includes pill, "$5"
    assert_includes pill, "$25"
  end

  test "the primary nav is Models and Events — the retired News feed and Trends page are gone" do
    labels = primary_nav_items.map(&:first)
    assert_equal %w[Models Events], labels
  end
end
