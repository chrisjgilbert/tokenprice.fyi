# One dated price step for a single model: the move from its previous snapshot
# to its current one. Distinct from AiModel::PriceChange, which measures a
# dimension against a trailing window or launch — this is the concrete step
# between two consecutive snapshots, mirroring a line in the Slack price-moves
# digest. Built through AiModel#latest_move; feeds the homepage "recent price
# changes" strip.
class PriceMove
  # A move in one dimension. `pct` is nil when it can't be computed (a dimension
  # introduced from nothing, or a zero base) — the strip shows the new figure
  # without a percentage there.
  Delta = Data.define(:dimension, :old, :new) do
    def pct
      return nil if old.nil? || new.nil? || old.zero?

      (((new - old) / old) * 100).round(1)
    end

    def direction
      change = pct
      return :flat if change.nil? || change.zero?

      change.positive? ? :up : :down
    end
  end

  DIMENSIONS = %i[input output cached].freeze
  COLUMNS = { input: :input_per_mtok, output: :output_per_mtok, cached: :cached_input_per_mtok }.freeze

  attr_reader :model_name, :model_slug, :provider_name, :provider_slug, :provider_accent,
              :effective_on, :deltas

  def initialize(model_name:, model_slug:, provider_name:, provider_slug:, provider_accent:,
                 effective_on:, deltas:)
    @model_name      = model_name
    @model_slug      = model_slug
    @provider_name   = provider_name
    @provider_slug   = provider_slug
    @provider_accent = provider_accent
    @effective_on    = effective_on
    @deltas          = deltas
  end

  # Nil when no priced dimension changed between the two snapshots, so a
  # re-confirmed price never shows as a move.
  def self.build(model, from:, to:)
    deltas = DIMENSIONS.filter_map do |dimension|
      was = from.public_send(COLUMNS[dimension])
      now = to.public_send(COLUMNS[dimension])
      Delta.new(dimension: dimension, old: was, new: now) unless was == now
    end
    return nil if deltas.empty?

    new(model_name: model.name, model_slug: model.slug,
        provider_name: model.provider.name, provider_slug: model.provider.slug,
        provider_accent: model.provider.accent,
        effective_on: to.effective_on, deltas: deltas)
  end

  def delta(dimension) = deltas.find { |d| d.dimension == dimension }
  def input  = delta(:input)
  def output = delta(:output)
  def cached = delta(:cached)

  # The dimension shown on the percent chip: the first (input → output → cached)
  # whose percentage is computable, falling back to the first change when none is.
  def headline
    deltas.find(&:pct) || deltas.first
  end
end
