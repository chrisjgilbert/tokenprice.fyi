# A proposed AiModel awaiting human review — the model-catalog analog of a draft
# MarketEvent. ModelCurationJob extracts one from a "release"-classified news_item
# (a new-model launch); a human approves or dismisses it in the admin review
# queue. Approving creates the real AiModel row (source: manual) via the
# ModelCandidate::Acceptance operation. Nothing here publishes automatically, and
# a candidate without a confirmable price is kept (price null, confidence "L")
# rather than filled with a guessed number.
class ModelCandidate < ApplicationRecord
  belongs_to :news_item, optional: true

  STATUSES = %w[pending accepted dismissed].freeze

  # A representative input/output modality signature per category, so acceptance
  # can build a model that derives the right modality_class (and thus lands in the
  # right tab). Directory categories key off their synthetic/native output. A test
  # guards that this covers every ModelCategory slug.
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

  # The representative input/output modality arrays for this candidate's category.
  def modalities = CATEGORY_SIGNATURE.fetch(category_slug, [ %w[text], %w[text] ])

  # The slug this candidate resolves to, derived from the name before it's
  # persisted (set_slug only fires on save) so dedup works on an unsaved candidate.
  def effective_slug = slug.presence || name&.parameterize

  # The catalog row this candidate would duplicate, if any — the dedup seam.
  def existing_model = (s = effective_slug) && AiModel.find_by(slug: s)

  def pricing_hash = @pricing_hash ||= (pricing.presence || {}).with_indifferent_access

  # Carries a native (per-image, per-search, …) price rather than a per-token one.
  def native_priced? = pricing_hash.values_at(:price_summary, :native_price_usd).any?(&:present?)

  # True when the candidate carries a usable price (per-token or native); a
  # price-less launch is valid — it becomes a "not yet tracked" row to price later.
  def priced? = native_priced? || pricing_hash.values_at(:input, :output).any?(&:present?)

  # Approve: create the manual AiModel row and mark accepted (reached only through
  # here, never ModelCandidate::Acceptance directly). Idempotent — a second accept
  # returns the row already created rather than duplicating it.
  def accept! = ModelCandidate::Acceptance.new(self).run

  def dismiss! = update!(status: "dismissed")

  # A short human-readable price for the review queue, in whatever native shape
  # the extraction found — or a prompt to price it when the launch stated none.
  # Formats through PriceFormat so it can't drift from the catalog's rendering.
  def price_preview
    hash = pricing_hash
    if hash[:price_summary].present?
      hash[:price_summary]
    elsif hash[:native_price_usd].present?
      "$#{PriceFormat.usd_amount(hash[:native_price_usd], decimals: 6)} #{hash[:native_price_unit]}".strip
    elsif hash[:input].present?
      "$#{PriceFormat.usd_amount(hash[:input])} / $#{PriceFormat.usd_amount(hash[:output])} per 1M tokens"
    else
      "— price to add"
    end
  end

  # A db/seeds.rb-style hash for this candidate, so a reviewer keeps the seed file
  # (the source of truth per docs/DATA_MAINTENANCE.md) in sync with a row created
  # by approval. A starting point to paste and tidy, not a guaranteed-final line.
  def seed_snippet
    input, output = modalities
    fields = {
      provider: provider_name.parameterize.to_sym.inspect,
      name: name.inspect,
      status: "active".inspect,
      input_modalities: input.inspect,
      output_modalities: output.inspect
    }
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
end
