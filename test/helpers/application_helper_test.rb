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
end
