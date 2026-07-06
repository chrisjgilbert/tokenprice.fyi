# An aggregate reading of the whole flagship set, so the /trends copy can
# comment on where the frontier has actually moved rather than narrate the
# chart the reader is already looking at. Every figure is computed from the
# trends, so the prose stays true as the data does.
class FlagshipTrend::Summary
  def initialize(trends)
    @trends = trends
  end

  def earliest = @trends.flat_map { |t| t.steps.map(&:date) }.min

  # Providers whose flagship launches cheaper / dearer today than the first one
  # tracked (input_change_pct compares first reign to current, so a flat 0 is
  # neither). Used both for the counts and to name the sharpest mover.
  def cheaper = compared.select { |t| t.input_change_pct.negative? }
  def pricier = compared.select { |t| t.input_change_pct.positive? }

  def biggest_cut  = cheaper.min_by(&:input_change_pct)
  def biggest_rise = pricier.max_by(&:input_change_pct)

  def compared? = compared.any?
  def mixed?    = cheaper.any? && pricier.any?

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

  def compared = @trends.select(&:input_change_pct)
end
