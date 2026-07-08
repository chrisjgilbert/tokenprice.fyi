# One dated price step for a single model: the move from its previous snapshot
# to its current one. Distinct from AiModel::PriceChange, which measures a
# dimension against a trailing window or launch — this is the concrete step
# between two consecutive snapshots, mirroring a line in the Slack price-moves
# digest. Built through AiModel#latest_move; feeds the homepage "recent price
# changes" strip.
PriceMove = Data.define(:model_name, :model_slug, :provider_name, :provider_slug,
                        :provider_accent, :effective_on, :deltas)

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
  # with a real, non-zero percentage — so a sub-rounding tweak in one dimension
  # never masks a meaningful move in another, and never renders a "0.0%" chip.
  # Falls back to any computable percentage, then to the first change.
  def headline
    deltas.find { |d| d.pct&.nonzero? } || deltas.find(&:pct) || deltas.first
  end
end
