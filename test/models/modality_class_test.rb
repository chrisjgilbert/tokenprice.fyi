require "test_helper"

class ModalityClassTest < ActiveSupport::TestCase
  # The signature → class table. image_generation is a directory class (any
  # image output); other non-text-output media signatures (audio, video) still
  # degrade to :other, pending the same treatment. [input, output, expected]
  TAXONOMY = [
    [ %w[text],              %w[text],       :text ],
    [ %w[image text],        %w[text],       :multimodal ],
    [ %w[image text video],  %w[text],       :multimodal ],
    [ %w[text],              %w[embedding],  :embedding ],
    [ %w[image],             %w[embedding],  :embedding ],
    [ %w[file],              %w[text],       :multimodal ],
    [ %w[video],             %w[file],       :other ],
    # Any image output is image generation — text-to-image, image editing, and
    # the image+text signature of a model like Gemini's image model ("nano
    # banana"), which must land here rather than in the omni catch-all.
    [ %w[text],              %w[image],      :image_generation ],
    [ %w[image text],        %w[image],      :image_generation ],
    [ %w[image text],        %w[image text], :image_generation ],
    # Any video output is video generation — text-to-video and image-to-video —
    # symmetric to image generation. Video INPUT with text output is video
    # understanding, which stays multimodal (below).
    [ %w[text],              %w[video],      :video_generation ],
    [ %w[image text],        %w[video],      :video_generation ],
    [ %w[text video],        %w[text],       :multimodal ],
    # Non-image, non-video, non-text output still degrades to :other for now.
    [ %w[text],              %w[audio],      :other ],
    # Audio-only input, text output is transcription — speech_to_text, decided
    # before multimodal. A chat model that also takes text ([text, audio]) stays
    # multimodal.
    [ %w[audio],             %w[text],       :speech_to_text ],
    [ %w[audio text],        %w[text],       :multimodal ],
    # A multi-output non-text signature with no image still catches any_to_any.
    [ %w[text],              %w[text audio], :any_to_any ]
  ].freeze

  TAXONOMY.each do |input, output, expected|
    test "#{input.inspect} -> #{output.inspect} classifies as #{expected}" do
      assert_equal expected, ModalityClass.for(input:, output:)
    end
  end

  test "the omni class is labelled Omnimodal" do
    assert_equal "Omnimodal", ModalityClass.label(:any_to_any)
  end

  test "image generation is labelled and marked a directory class" do
    assert_equal "Image generation", ModalityClass.label(:image_generation)
    assert ModalityClass.directory_class?(:image_generation)
    assert ModalityClass.directory_class?("image_generation")
    refute ModalityClass.directory_class?(:text)
    refute ModalityClass.directory_class?(:any_to_any)
  end

  test "speech to text is labelled and marked a directory class" do
    assert_equal "Speech to text", ModalityClass.label(:speech_to_text)
    assert ModalityClass.directory_class?(:speech_to_text)
    assert ModalityClass.directory_class?("speech_to_text")
  end

  test "video generation is labelled and marked a directory class" do
    assert_equal "Video generation", ModalityClass.label(:video_generation)
    assert ModalityClass.directory_class?(:video_generation)
    assert ModalityClass.directory_class?("video_generation")
  end

  test "video output classifies as video_generation; video input stays multimodal" do
    assert_equal :video_generation, ModalityClass.for(input: %w[text], output: %w[video])
    assert_equal :video_generation, ModalityClass.for(input: %w[image text], output: %w[video])
    assert_equal :multimodal, ModalityClass.for(input: %w[text video], output: %w[text])
  end

  test "audio-only input to text classifies as speech_to_text before multimodal" do
    assert_equal :speech_to_text, ModalityClass.for(input: %w[audio], output: %w[text])
    assert_equal :multimodal, ModalityClass.for(input: %w[audio text], output: %w[text])
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

  test "video understanding (video input, text output) classifies as multimodal" do
    assert_equal :multimodal, ModalityClass.for(input: %w[text video], output: %w[text])
  end
end
