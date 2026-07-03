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

  # Percent change in flagship input price from the first tracked flagship to the
  # current one (negative = cheaper). Nil when there's a single flagship or the
  # base is zero — nothing to compare.
  def input_change_pct
    from = launch.input
    to   = current.input
    return nil if steps.size < 2 || from.nil? || to.nil? || from.zero?

    (((to - from) / from) * 100).round
  end

  class << self
    # Freshness stamp for conditional GET on the trends page. The chart is driven
    # by frontier-model metadata (name, released_on, tier, status) as much as by
    # prices, and none of those writes touch a price row — a tier flip even moves
    # a model in or out of the series — so fold in the newest AiModel write, not
    # just PriceCatalog's price-point stamp. (The daily x-axis advance is handled
    # separately, by dating the controller's etag.)
    def last_modified
      [ PriceCatalog.last_modified, AiModel.maximum(:updated_at) ].compact.max
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
