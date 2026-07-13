# An aggregate reading of the whole flagship set, so the /trends copy can
# comment on where the frontier has actually moved rather than narrate the
# chart the reader is already looking at. Every figure is computed from the
# trends, so the prose stays true as the data does.
#
# Both figures are robust to who's in the set and to where our data starts —
# unlike a per-provider "% since first", which reads as a price hike whenever a
# lab debuted with an unusually cheap model. The floor is a running minimum; the
# span is today's dispersion.
class FlagshipTrend::Summary
  def initialize(trends)
    @trends = trends
  end

  def earliest = steps.map(&:date).min

  # How far the cheapest frontier input price has fallen: the earliest flagship
  # on record against the lowest-priced one ever launched. `from`/`to` are Steps
  # (so the copy can name the model and date). Tie-breaks are explicit so the
  # figure is stable across rebuilds. Nil unless the fall rounds to a real ≥2×
  # (a smaller drop would round to a nonsense "1× cheaper").
  def floor_drop
    return if steps.size < 2

    from = steps.min_by { |s| [ s.date, -s.input ] }
    to   = steps.min_by { |s| [ s.input, s.date ] }
    multiple = (from.input / to.input).round
    return if multiple < 2

    { from:, to:, multiple: }
  end

  # Spread of today's flagship input prices — the dispersion the chart shows but
  # can't put a number on. Nil unless at least two are positively priced and the
  # spread rounds to a real multiple (a sub-2× spread isn't worth a "range"
  # claim, and 1× reads as no spread at all).
  def price_span
    prices = @trends.map { |t| t.current.input }.compact.select(&:positive?)
    return if prices.size < 2

    low, high = prices.minmax
    multiple = (high / low).round
    return if multiple < 2

    { low:, high:, multiple: }
  end

  private

  def steps = @trends.flat_map(&:steps)
end
