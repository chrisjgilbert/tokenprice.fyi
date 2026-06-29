require "test_helper"

class ModalityClassTest < ActiveSupport::TestCase
  # One row per line of the taxonomy table in docs/MULTIMODAL_PRICING_PLAN.md.
  # [input, output, expected_class]
  TAXONOMY = [
    [ %w[text],              %w[text],      :text ],
    [ %w[image text],        %w[text],      :multimodal ],
    [ %w[image text video],  %w[text],      :multimodal ],
    [ %w[text],              %w[embedding], :embedding ],
    [ %w[image],             %w[embedding], :embedding ],
    [ %w[image text],        %w[image text], :any_to_any ],
    [ %w[file],              %w[text],      :multimodal ],
    [ %w[video],             %w[file],      :other ],
    # Non-text-output media signatures are no longer priced or classed; they
    # degrade to :other rather than image_generation / text_to_audio / etc.
    [ %w[text],              %w[image],     :other ],
    [ %w[text],              %w[audio],     :other ],
    [ %w[audio],             %w[text],      :multimodal ],
    [ %w[text],              %w[video],     :other ]
  ].freeze

  TAXONOMY.each do |input, output, expected|
    test "#{input.inspect} -> #{output.inspect} classifies as #{expected}" do
      assert_equal expected, ModalityClass.for(input:, output:)
    end
  end

  test "the omni class is labelled Omnimodal" do
    assert_equal "Omnimodal", ModalityClass.label(:any_to_any)
  end

  test "empty input and output degrade to text" do
    assert_equal :text, ModalityClass.for(input: [], output: [])
  end

  test "empty input with text output degrades to text" do
    assert_equal :text, ModalityClass.for(input: [], output: %w[text])
  end

  test "unsorted, duplicated and uppercase modalities normalise before classifying" do
    assert_equal :multimodal, ModalityClass.for(input: %w[TEXT Image image], output: %w[Text])
    assert_equal :text, ModalityClass.for(input: %w[TEXT text], output: %w[TEXT])
  end

  test "unknown modality tokens are dropped before classifying" do
    assert_equal :text, ModalityClass.for(input: %w[text mystery], output: %w[text])
  end

  test "an unmatched signature falls through to other" do
    assert_equal :other, ModalityClass.for(input: %w[video], output: %w[file])
  end

  test "video understanding (video input, text output) stays multimodal not video_generation" do
    assert_equal :multimodal, ModalityClass.for(input: %w[text video], output: %w[text])
  end
end
