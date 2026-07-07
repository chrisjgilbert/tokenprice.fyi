# Derives a single filterable class from a model's modality signature — the set
# of inputs it accepts and the set it produces. The derivation table lives in
# docs/MULTIMODAL_PRICING_PLAN.md; this is its one executable home, so a
# reclassification is a code change here rather than a data backfill.
#
# A value object in the codebase's style: no state worth holding, just a pure
# function over two modality sets exposed as `ModalityClass.for(input:, output:)`.
#
# Most classes here bill per token — text, multimodal (non-text input → text
# output), embedding, and the catch-all omnimodal (any_to_any). Two "directory
# classes" are admitted without a per-token price: image_generation (native
# per-image price) and speech_to_text (native per-minute price), each curated
# separately and reading "not yet tracked" until then (see DIRECTORY_CLASSES,
# docs/IMAGE_CATEGORY_PLAN.md, and docs/SPEECH_TO_TEXT_TAB_PLAN.md). Other
# non-text-output media signatures (TTS, video, …) still degrade to :other,
# pending the same treatment.
class ModalityClass
  # Closed modality vocabulary. Anything outside this is dropped before
  # classifying so a stray token from the source can't reshape the signature.
  VOCABULARY = %w[text image audio video file embedding].freeze

  # Classes we list without a per-token price: their native unit (per image, …)
  # is curated, so a row can be listed and filterable before it's priced. The
  # one place that knows which classes get the "not yet tracked" treatment.
  DIRECTORY_CLASSES = %i[image_generation speech_to_text].freeze

  def self.directory_class?(symbol) = DIRECTORY_CLASSES.include?(symbol.to_sym)

  def self.for(input:, output:)
    new(input, output).classify
  end

  # Human-readable labels for the UI, naming the fact rather than a marketing
  # term (per the plan's copy rules): "Omnimodal", not "any-to-any". The keys are
  # the full class set — the signature-derived rules plus :other.
  LABELS = {
    text:             "Text",
    multimodal:       "Multimodal",
    image_generation: "Image generation",
    speech_to_text:   "Speech to text",
    embedding:        "Embedding",
    any_to_any:       "Omnimodal",
    other:            "Other"
  }.freeze

  def self.label(symbol) = LABELS.fetch(symbol.to_sym, symbol.to_s.tr("_", " ").capitalize)

  # One-line descriptions for the filter legend, naming each class by its
  # input→output shape — the same signature the rules below match on, in plain words.
  DESCRIPTIONS = {
    text:             "Text in, text out.",
    multimodal:       "Accepts images, audio, or other media as input; produces text.",
    image_generation: "Text (and optionally an image) in, an image out.",
    speech_to_text:   "Audio in, a text transcript out.",
    embedding:        "Text or an image in, a vector embedding out.",
    any_to_any:       "Produces several output modalities, including non-text.",
    other:            "Modality signatures that don't fit the categories above."
  }.freeze

  def self.description(symbol) = DESCRIPTIONS.fetch(symbol.to_sym, nil)

  # [label, description] rows for the modality filter legend.
  def self.legend_entries(symbols) = symbols.map { |symbol| [ label(symbol), description(symbol) ] }

  # Clean a raw token list: lowercase, drop tokens outside the closed
  # vocabulary, dedup — preserving order so callers that persist or display a
  # signature keep the source's reading order (text first, typically). The
  # classifier sorts on top of this for its own order-independent matching.
  def self.normalize(modalities)
    Array(modalities)
      .map { |m| m.to_s.downcase }
      .select { |m| VOCABULARY.include?(m) }
      .uniq
  end

  def initialize(input, output)
    @input  = self.class.normalize(input).sort
    @output = self.class.normalize(output).sort
  end

  def classify
    return :text if @input.empty? && (text_output? || @output.empty?)

    SIGNATURE_RULES.each { |label, rule| return label if instance_exec(&rule) }
    :other
  end

  private

  def text_output?      = @output == %w[text]
  def embedding_output? = @output == %w[embedding]

  def nontext_input? = @input.any? { |m| m != "text" }

  # Each rule is evaluated in order against the normalised signature; the first
  # truthy match wins. speech_to_text sits before multimodal deliberately: an
  # audio-ONLY input is transcription, but a chat model that also takes text
  # ([text, audio]) is multimodal, so the narrower audio-only rule must run first.
  # image_generation sits before any_to_any deliberately: a
  # model that emits an image is doing image generation in the visitor's mental
  # model whether or not it also emits text, so an image+text signature (e.g.
  # Gemini's image model) lands in image_generation, not the omni catch-all.
  # any_to_any is last: the catch for a signature producing several modalities
  # including a non-text one.
  SIGNATURE_RULES = {
    text:             -> { @input == %w[text] && text_output? },
    speech_to_text:   -> { @input == %w[audio] && text_output? },
    multimodal:       -> { nontext_input? && text_output? },
    image_generation: -> { @output.include?("image") },
    embedding:        -> { (@input - %w[image text]).empty? && @input.any? && embedding_output? },
    any_to_any:       -> { @output.size > 1 && @output.any? { |m| m != "text" } }
  }.freeze
end
