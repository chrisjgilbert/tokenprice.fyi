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

  test "modality_signature renders a multimodal signature in reading order" do
    model = AiModel.new(input_modalities: %w[text image], output_modalities: %w[text])
    assert_equal "Text, image in → text out", modality_signature(model)
  end

  test "modality_signature is suppressed for a plain text model" do
    model = AiModel.new(input_modalities: %w[text], output_modalities: %w[text])
    assert_nil modality_signature(model)
  end

  test "modality_signature is suppressed when only one side is recorded" do
    model = AiModel.new(input_modalities: %w[text image], output_modalities: [])
    assert_nil modality_signature(model)
  end

  test "modality_signature agrees with the badge: a cased text-only signature stays suppressed" do
    model = AiModel.new(input_modalities: %w[TEXT], output_modalities: %w[Text])
    assert_nil modality_badge(model)
    assert_nil modality_signature(model)
  end

  test "modality_badge names the class for a multimodal model and is nil for text" do
    multimodal = AiModel.new(input_modalities: %w[text image], output_modalities: %w[text])
    assert_includes modality_badge(multimodal), "Multimodal"
    assert_nil modality_badge(AiModel.new(input_modalities: %w[text], output_modalities: %w[text]))
  end

  test "directory_row? is true for a price-less non-text model and false for a price-less text model" do
    assert directory_row?(ai_models(:image_gen)), "price-less image-gen row is a directory row"
    refute directory_row?(ai_models(:no_price)), "price-less text row is not a directory row"
  end

  test "io_price shows the untracked note for a directory row, never a dash pill" do
    pill = io_price(ai_models(:image_gen))
    assert_includes pill, "Not yet tracked"
    assert_not_includes pill, "—"
  end
end
