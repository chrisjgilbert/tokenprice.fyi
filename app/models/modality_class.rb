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
    speech_to_speech: "Speech to speech",
    image_generation: "Image generation",
    image_editing:    "Image editing",
    video_generation: "Video generation",
    embedding:        "Embedding",
    any_to_any:       "Omnimodal",
    other:            "Other"
  }.freeze

  def self.label(symbol) = LABELS.fetch(symbol.to_sym, symbol.to_s.tr("_", " ").capitalize)

  # One-line filter tooltips naming each class by its input→output shape — the
  # same signature the rules below match on, said in plain words.
  DESCRIPTIONS = {
    text:             "Text in, text out.",
    multimodal:       "Accepts images, audio, or other media as input; produces text.",
    text_to_audio:    "Text in, audio out — text-to-speech.",
    audio_to_text:    "Audio in, text out — transcription.",
    speech_to_speech: "Audio in, audio out.",
    image_generation: "Text, optionally with an image, in; a generated image out.",
    image_editing:    "An image in, an edited image out.",
    video_generation: "Text or an image in, generated video out.",
    embedding:        "Text or an image in, a vector embedding out.",
    any_to_any:       "Produces several output modalities, including non-text.",
    other:            "Modality signatures that don't fit the categories above."
  }.freeze

  def self.description(symbol) = DESCRIPTIONS.fetch(symbol.to_sym, nil)

  # The classes that bill in a NON-token unit, mapped to that unit. These are the
  # only classes we admit to the catalogue without a price (a "directory" row,
  # priced "per image / per second — not yet tracked" until Phase 3 quotes the
  # real rate). Everything else — text, multimodal, embedding, any_to_any — is
  # priced per token (or per input token); a price-less one of those is just a
  # model we lack data for, not a directory entry, so it stays unlisted.
  # Each class names the unit its real list prices are quoted in, not a uniform
  # "per second": TTS bills per character (OpenAI tts-1 is $15 / 1M characters),
  # speech-to-text per minute of audio (Whisper is $0.006 / minute), image models
  # per generated image, and video per second of output. A seeded native price is
  # only meaningful paired with the unit it was quoted in, so these must match the
  # provider's billing.
  DIRECTORY_PRICE_UNITS = {
    image_generation: "per image",
    image_editing:    "per image",
    text_to_audio:    "per 1M characters",
    audio_to_text:    "per minute",
    speech_to_speech: "per minute",
    video_generation: "per second"
  }.freeze

  # The class symbols admitted as price-less directory rows, as strings — for the
  # `listed` SQL scope's IN-list.
  DIRECTORY_CLASS_NAMES = DIRECTORY_PRICE_UNITS.keys.map(&:to_s).freeze

  # Whether a class is one we'd list without a price (non-token billing).
  def self.directory_class?(symbol) = DIRECTORY_PRICE_UNITS.key?(symbol.to_sym)

  # The non-token billing unit for a directory class, or nil for token-priced ones.
  def self.price_unit(symbol) = DIRECTORY_PRICE_UNITS[symbol.to_sym]

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

  def text_output?  = @output == %w[text]
  def audio_output? = @output == %w[audio]
  def image_output? = @output == %w[image]
  def video_output? = @output == %w[video]
  def embedding_output? = @output == %w[embedding]

  def input_includes?(*modalities) = modalities.all? { |m| @input.include?(m) }
  def nontext_input? = @input.any? { |m| m != "text" }

  # Each rule is evaluated in order against the normalised signature; the first
  # truthy match wins. image_editing precedes image_generation because an
  # image-input → {image} signature satisfies both and the editing case (it has
  # an image to work from, with or without a text prompt) is the more specific
  # one; image_generation is the text-only-input → {image} case. any_to_any is
  # last among the matches: it's the catch for a signature that produces several
  # modalities including a non-text one.
  SIGNATURE_RULES = {
    text:             -> { @input == %w[text] && text_output? },
    text_to_audio:    -> { @input == %w[text] && audio_output? },
    audio_to_text:    -> { input_includes?("audio") && (@input - %w[audio text]).empty? && text_output? },
    speech_to_speech: -> { @input == %w[audio] && audio_output? },
    multimodal:       -> { nontext_input? && text_output? },
    image_editing:    -> { input_includes?("image") && (@input - %w[image text]).empty? && image_output? },
    image_generation: -> { (@input - %w[image text]).empty? && input_includes?("text") && image_output? },
    video_generation: -> { (@input - %w[image text]).empty? && @input.any? && video_output? },
    embedding:        -> { (@input - %w[image text]).empty? && @input.any? && embedding_output? },
    any_to_any:       -> { @output.size > 1 && @output.any? { |m| m != "text" } }
  }.freeze
end
