# Derives a single filterable class from a model's modality signature — the set
# of inputs it accepts and the set it produces. The derivation table lives in
# docs/MULTIMODAL_PRICING_PLAN.md; this is its one executable home, so a
# reclassification is a code change here rather than a data backfill.
#
# A value object in the codebase's style: no state worth holding, just a pure
# function over two modality sets exposed as `ModalityClass.for(input:, output:)`.
class ModalityClass
  # Closed modality vocabulary. Anything outside this is dropped before
  # classifying so a stray token from the source can't reshape the signature.
  VOCABULARY = %w[text image audio video file embedding].freeze

  # The signature-derivable classes, in match order. Two task-typed classes from
  # the plan — `rerank` and moderation — are NOT here: their output is scores or
  # labels, not a media modality, so they're resolved from an OpenRouter endpoint
  # hint, not the signature. That's Phase 2; this object only sees signatures and
  # callers only ever get a resolved symbol, so adding the hint later won't
  # reshape this surface.
  def self.for(input:, output:)
    new(input, output).classify
  end

  # Human-readable labels for the UI, naming the fact rather than a marketing
  # term (per the plan's copy rules): "Speech to text", not "STT". The keys are
  # the full class set — the signature-derived rules plus :other.
  LABELS = {
    text:             "Text",
    multimodal:       "Multimodal",
    text_to_audio:    "Text to audio",
    audio_to_text:    "Speech to text",
    speech_to_speech: "Realtime voice",
    image_generation: "Image generation",
    image_editing:    "Image editing",
    video_generation: "Video generation",
    embedding:        "Embedding",
    any_to_any:       "Any to any",
    other:            "Other"
  }.freeze

  def self.label(symbol) = LABELS.fetch(symbol.to_sym, symbol.to_s.tr("_", " ").capitalize)

  def initialize(input, output)
    @input  = normalize(input)
    @output = normalize(output)
  end

  def classify
    return :text if @input.empty? && (text_output? || @output.empty?)

    SIGNATURE_RULES.each { |label, rule| return label if instance_exec(&rule) }
    :other
  end

  private

  def normalize(modalities)
    Array(modalities)
      .map { |m| m.to_s.downcase }
      .select { |m| VOCABULARY.include?(m) }
      .uniq
      .sort
  end

  def text_output?  = @output == %w[text]
  def audio_output? = @output == %w[audio]
  def image_output? = @output == %w[image]
  def video_output? = @output == %w[video]
  def embedding_output? = @output == %w[embedding]

  def input_includes?(*modalities) = modalities.all? { |m| @input.include?(m) }
  def input_only?(*modalities) = @input == modalities.sort.uniq
  def nontext_input? = @input.any? { |m| m != "text" }

  # Each rule is evaluated in order against the normalised signature; the first
  # truthy match wins. image_editing precedes image_generation because an
  # {image, text} → {image} signature satisfies both and the editing case is the
  # more specific one. any_to_any is last among the matches: it's the catch for a
  # signature that produces several modalities including a non-text one.
  SIGNATURE_RULES = {
    text:             -> { @input == %w[text] && text_output? },
    text_to_audio:    -> { @input == %w[text] && audio_output? },
    audio_to_text:    -> { input_includes?("audio") && (@input - %w[audio text]).empty? && text_output? },
    speech_to_speech: -> { @input == %w[audio] && audio_output? },
    multimodal:       -> { nontext_input? && text_output? },
    image_editing:    -> { input_only?("image", "text") && image_output? },
    image_generation: -> { (@input - %w[image text]).empty? && input_includes?("text") && image_output? },
    video_generation: -> { (@input - %w[image text]).empty? && @input.any? && video_output? },
    embedding:        -> { (@input - %w[image text]).empty? && @input.any? && embedding_output? },
    any_to_any:       -> { @output.size > 1 && @output.any? { |m| m != "text" } }
  }.freeze
end
