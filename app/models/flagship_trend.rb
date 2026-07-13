# One provider's flagship — its most-powerful (frontier-tier) model — priced as
# it stepped over time. Each new frontier release becomes a step: from its
# release date forward, the provider's flagship costs what that model cost at
# launch. Read as a step function (a price holds until the next flagship
# supersedes it), which is exactly how the chart draws it.
#
# "Launch price of the reigning flagship" is the honest series here: released_on
# is the x-axis, and only a handful of models were ever repriced mid-life, so
# threading later price cuts through would add noise for almost no signal. The
# chart copy states this framing.
#
# Built by reading *through* PriceCatalog (never ad hoc AiModel queries), so the
# trend stays on the same seam as the rest of the read side.
class FlagshipTrend
  # One flagship's reign, anchored at its release. `input`/`output` are the
  # launch price in USD per 1M tokens.
  Step = Data.define(:date, :model_name, :model_slug, :input, :output)

  # One point on the cheapest-frontier floor line: the lowest flagship input
  # price available anywhere on `date`.
  FloorPoint = Data.define(:date, :input)

  attr_reader :provider_name, :provider_slug, :accent, :steps

  def initialize(provider_name:, provider_slug:, accent:, steps:)
    @provider_name = provider_name
    @provider_slug = provider_slug
    @accent        = accent
    @steps         = steps
  end

  # The reigning flagship today (the most recent release) and the first one on
  # record — the two ends of the line.
  def current = steps.last
  def launch  = steps.first

  # The [min, max] launch price this provider's flagships have spanned, per
  # dimension. Input is always present; output can be nil on a flagship we don't
  # have an output rate for, so it's compacted and nil when none is known.
  def input_range = steps.map(&:input).minmax

  def output_range
    outputs = steps.filter_map(&:output)
    outputs.minmax if outputs.any?
  end

  # This provider's flagship input price in effect on `date` — the latest release
  # on or before it — or nil if it hadn't shipped a frontier model yet. Feeds the
  # cross-provider floor line.
  def input_as_of(date)
    steps.select { |s| s.date <= date }.last&.input
  end

  class << self
    # Freshness stamp for conditional GET on the trends page. The chart is driven
    # by prices, frontier-model metadata (name, released_on, tier, status — a tier
    # flip even moves a model in or out of the series), and provider rows (the
    # legend names, line colours, and links), and edits to the latter two touch no
    # price row — so fold in the newest AiModel and Provider writes, not just
    # PriceCatalog's price-point stamp. (The daily x-axis advance is handled
    # separately, by dating the controller's etag.)
    def last_modified
      [ PriceCatalog.last_modified,
        AiModel.maximum(:updated_at),
        Provider.maximum(:updated_at) ].compact.max
    end

    # One trend per provider that has at least one priced frontier model with a
    # release date, richest histories first so the busiest lines lead the legend.
    # Reads the full frontier history (superseded models included) — they're the
    # former flagships the timeline is made of.
    def all(catalog: PriceCatalog.frontier_history)
      catalog
        .select { |e| frontier_flagship?(e) }
        .group_by(&:provider_slug)
        .values
        .map { |entries| build(entries) }
        .sort_by { |t| [ -t.steps.size, t.provider_name ] }
    end

    # The cheapest frontier input price available at each point in time — the min
    # across providers of their in-effect flagship. A step series (one point per
    # release date across all providers) for the chart's floor line. The pool of
    # providers grows over time; a cheaper new entrant genuinely lowers the floor,
    # which is the point (unlike a mean, this isn't distorted by who's in the set).
    def floor_series(trends = all)
      dates = trends.flat_map { |t| t.steps.map(&:date) }.uniq.sort
      dates.filter_map do |date|
        prices = trends.filter_map { |t| t.input_as_of(date) }
        FloorPoint.new(date: date, input: prices.min) if prices.any?
      end
    end

    private

    # A frontier model we can place on the timeline: it has a release date and a
    # positive launch input price to anchor the step (the chart's log axis can't
    # plot 0, and a $0 "price" isn't a real flagship rate anyway).
    def frontier_flagship?(entry)
      entry.tier == "frontier" && entry.released_on && entry.snapshots.first&.input&.positive?
    end

    def build(entries)
      ordered = entries.sort_by(&:released_on)
      steps = ordered.map do |e|
        launch = e.snapshots.first
        Step.new(date: e.released_on, model_name: e.name, model_slug: e.slug,
                 input: launch.input, output: launch.output)
      end
      first = ordered.first
      new(provider_name: first.provider_name, provider_slug: first.provider_slug,
          accent: first.provider_accent, steps: steps)
    end
  end
end
