# Creates the real AiModel row from an approved ModelCandidate — the write half of
# the detection→curation bridge, reached only through ModelCandidate#accept!. Like
# the OpenRouter sync, this coordinates a write across Provider, AiModel, and
# PricePoint that belongs to no single record, so it lives in a noun-named
# operation rather than inline on the model (mirroring the read half,
# NewsItem::ModelExtraction). Idempotent: re-accepting returns the row already
# created rather than duplicating it.
class ModelCandidate::Acceptance
  def initialize(candidate)
    @candidate = candidate
  end

  def run
    return candidate.existing_model if candidate.status == "accepted" && candidate.existing_model

    model = ModelCandidate.transaction do
      m = build_model(find_or_create_provider)
      m.save!
      apply_token_price(m)
      candidate.update!(status: "accepted")
      m
    end

    # The extraction captures only identity, category, and price, so an approved
    # model starts with no description / strengths / best-for / limitations. Fill
    # the editorial copy out of band — mirrors EventCurationJob enqueuing
    # MarketEventInsightJob after drafting an event. Enqueued post-commit so the
    # job never runs against an uncommitted row.
    AiModelDescriptionJob.perform_later(model)
    model
  end

  private

  attr_reader :candidate

  def find_or_create_provider
    Provider.find_or_create_by!(slug: candidate.provider_name.parameterize) { |p| p.name = candidate.provider_name }
  end

  def build_model(provider)
    input, output = candidate.modalities
    hash = candidate.pricing_hash
    provider.ai_models.new(
      name:              candidate.name,
      slug:              candidate.slug,
      status:            "active",
      source:            AiModel::MANUAL_SOURCE,
      released_on:       candidate.released_on,
      input_modalities:  input,
      output_modalities: output,
      context_window:    hash[:context_window],
      pricing_model:     hash[:pricing_model],
      price_summary:     hash[:price_summary],
      native_price_usd:  hash[:native_price_usd],
      native_price_unit: hash[:native_price_unit],
      price_detail:      hash[:price_detail],
      price_source:      candidate.source_url.presence,
      priced_as_of:      (Date.current if candidate.native_priced?)
    )
  end

  # Per-token categories (language, embeddings) carry the price as a PricePoint,
  # not native columns; create it when the extraction found a token rate. A
  # native-priced candidate keeps its price in columns even if a stray input rate
  # slipped into the extraction, so it never grows a misleading per-token point.
  def apply_token_price(model)
    return if candidate.native_priced?

    hash = candidate.pricing_hash
    return unless hash[:input].present? || hash[:output].present?

    model.price_points.create!(
      effective_on:    Date.current,
      input_per_mtok:  hash[:input],
      output_per_mtok: hash[:output],
      source:          candidate.source_url.presence || "curation"
    )
  end
end
