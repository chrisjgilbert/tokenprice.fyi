# Derives a single filterable class from a model's modality signature — the set
# of inputs it accepts and the set it produces. The derivation table lives in
# docs/MULTIMODAL_PRICING_PLAN.md; this is its one executable home, so a
# reclassification is a code change here rather than a data backfill.
#
# A value object in the codebase's style: no state worth holding, just a pure
# function over two modality sets exposed as `ModalityClass.for(input:, output:)`.
#
# The site tracks token-priced models only, so the taxonomy stops at classes that
# bill per token: text, multimodal (non-text input → text output), embedding, and
# the catch-all omnimodal (any_to_any). A non-text-output media model (image-gen,
# TTS, video, …) isn't priced here and degrades to :other.
class ModalityClass
  # Closed modality vocabulary. Anything outside this is dropped before
  # classifying so a stray token from the source can't reshape the signature.
  VOCABULARY = %w[text image audio video file embedding].freeze

  def self.for(input:, output:)
    new(input, output).classify
  end

  # Human-readable labels for the UI, naming the fact rather than a marketing
  # term (per the plan's copy rules): "Omnimodal", not "any-to-any". The keys are
  # the full class set — the signature-derived rules plus :other.
  LABELS = {
    text:       "Text",
    multimodal: "Multimodal",
    embedding:  "Embedding",
    any_to_any: "Omnimodal",
    other:      "Other"
  }.freeze

  def self.label(symbol) = LABELS.fetch(symbol.to_sym, symbol.to_s.tr("_", " ").capitalize)

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
  # truthy match wins. any_to_any is last: it's the catch for a signature that
  # produces several modalities including a non-text one.
  SIGNATURE_RULES = {
    text:       -> { @input == %w[text] && text_output? },
    multimodal: -> { nontext_input? && text_output? },
    embedding:  -> { (@input - %w[image text]).empty? && @input.any? && embedding_output? },
    any_to_any: -> { @output.size > 1 && @output.any? { |m| m != "text" } }
  }.freeze
end
