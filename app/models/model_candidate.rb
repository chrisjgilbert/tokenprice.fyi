# A proposed AiModel awaiting human review — the model-catalog analog of a draft
# MarketEvent. ModelCurationJob extracts one from a "release"-classified news_item
# (a new-model launch); a human approves or dismisses it in the admin review
# queue. Approving creates the real AiModel row (source: manual). Nothing here
# publishes automatically, and a candidate without a confirmable price is kept
# (price null, confidence "L") rather than filled with a guessed number.
class ModelCandidate < ApplicationRecord
  belongs_to :news_item, optional: true

  STATUSES = %w[pending accepted dismissed].freeze

  # A representative input/output modality signature per category, so accept! can
  # build a model that derives the right modality_class (and thus lands in the
  # right tab). Directory categories key off their synthetic/native output.
  CATEGORY_SIGNATURE = {
    "language"       => [ %w[text],  %w[text] ],
    "embeddings"     => [ %w[text],  %w[embedding] ],
    "rerank"         => [ %w[text],  %w[rerank] ],
    "speech-to-text" => [ %w[audio], %w[text] ],
    "text-to-speech" => [ %w[text],  %w[audio] ],
    "image"          => [ %w[text],  %w[image] ],
    "video"          => [ %w[text],  %w[video] ]
  }.freeze

  validates :name, :provider_name, :slug, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :source_url, format: { with: %r{\Ahttps?://\S+\z}i, message: "must be an http(s) URL" },
                         allow_blank: true

  before_validation :set_slug, on: :create

  scope :pending,      -> { where(status: "pending") }
  scope :recent_first, -> { order(created_at: :desc) }

  # The category this candidate lands in, or nil when the extractor's slug is
  # unknown (a signature we don't yet have a tab for).
  def category = category_slug.present? ? ModelCategory.for(category_slug) : nil

  # The slug this candidate resolves to, derived from the name before it's
  # persisted (set_slug only fires on save) so dedup works on an unsaved candidate.
  def effective_slug = slug.presence || name&.parameterize

  # The catalog row this candidate would duplicate, if any — the dedup seam.
  def existing_model = (s = effective_slug) && AiModel.find_by(slug: s)

  def pricing_hash = (pricing.presence || {}).with_indifferent_access

  # True when the candidate carries a usable price (per-token or native); a
  # price-less launch is valid — it becomes a "not yet tracked" row to price later.
  def priced?
    hash = pricing_hash
    hash.values_at(:input, :output, :price_summary, :native_price_usd).any?(&:present?)
  end

  # Approve: create the manual AiModel row and mark accepted. Idempotent — a
  # second accept returns the row already created rather than duplicating it.
  def accept!
    return existing_model if status == "accepted" && existing_model

    transaction do
      provider = Provider.find_or_create_by!(slug: provider_name.parameterize) { |p| p.name = provider_name }
      model = build_model(provider)
      model.save!
      apply_token_price(model)
      update!(status: "accepted")
      model
    end
  end

  def dismiss! = update!(status: "dismissed")

  # A short human-readable price for the review queue, in whatever native shape
  # the extraction found — or a prompt to price it when the launch stated none.
  def price_preview
    hash = pricing_hash
    if hash[:price_summary].present? then hash[:price_summary]
    elsif hash[:native_price_usd].present? then "$#{hash[:native_price_usd]} #{hash[:native_price_unit]}".strip
    elsif hash[:input].present? then "$#{hash[:input]} / $#{hash[:output]} per 1M tokens"
    else "— price to add"
    end
  end

  # A db/seeds.rb-style hash for this candidate, so a reviewer keeps the seed file
  # (the source of truth per docs/DATA_MAINTENANCE.md) in sync with a row created
  # by approval. A starting point to paste and tidy, not a guaranteed-final line.
  def seed_snippet
    fields = {
      provider: provider_name.parameterize.to_sym.inspect,
      name: name.inspect,
      tier: (pricing_hash[:tier].presence || "mid").inspect,
      status: "active".inspect
    }
    input, output = CATEGORY_SIGNATURE.fetch(category_slug, [ %w[text], %w[text] ])
    fields[:input_modalities]  = input.inspect
    fields[:output_modalities] = output.inspect
    %i[pricing_model price_summary native_price_usd native_price_unit price_detail].each do |key|
      value = pricing_hash[key]
      fields[key] = value.inspect if value.present?
    end
    fields[:price_source] = source_url.inspect if source_url.present?
    "{ #{fields.map { |k, v| "#{k}: #{v}" }.join(", ")} }"
  end

  private

  def set_slug
    self.slug ||= name&.parameterize
  end

  def build_model(provider)
    input, output = CATEGORY_SIGNATURE.fetch(category_slug, [ %w[text], %w[text] ])
    provider.ai_models.new(
      name:              name,
      slug:              slug,
      tier:              pricing_hash[:tier].presence || "mid",
      status:            "active",
      source:            AiModel::MANUAL_SOURCE,
      released_on:       released_on,
      input_modalities:  input,
      output_modalities: output,
      context_window:    pricing_hash[:context_window],
      pricing_model:     pricing_hash[:pricing_model],
      price_summary:     pricing_hash[:price_summary],
      native_price_usd:  pricing_hash[:native_price_usd],
      native_price_unit: pricing_hash[:native_price_unit],
      price_detail:      pricing_hash[:price_detail],
      price_source:      source_url.presence,
      priced_as_of:      (Date.current if native_priced?)
    )
  end

  # Per-token categories (language, embeddings) carry the price as a PricePoint,
  # not native columns; create it when the extraction found a token rate. A
  # native-priced candidate keeps its price in columns even if a stray input rate
  # slipped into the extraction, so it never grows a misleading per-token point.
  def apply_token_price(model)
    return if native_priced?

    hash = pricing_hash
    return unless hash[:input].present? || hash[:output].present?

    model.price_points.create!(
      effective_on:    Date.current,
      input_per_mtok:  hash[:input],
      output_per_mtok: hash[:output],
      source:          source_url.presence || "curation"
    )
  end

  def native_priced?
    pricing_hash.values_at(:price_summary, :native_price_usd).any?(&:present?)
  end
end
