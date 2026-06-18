# The single read interface for price data. The estimator, the model-page
# embed, the education widgets, and the public JSON API all read prices
# *through here* — never via ad hoc AiModel queries — so the future
# measure-&-optimize product stays cleanly separable and can later swap or
# extend data sources without touching its consumers. Backed by AiModel today.
#
# Everything is exposed as small value objects (Entry / Snapshot) rather than
# ActiveRecord, so consumers depend on the interface, not the table.
class PriceCatalog
  # A single dated price observation, normalized to USD per 1M tokens.
  # `cached` is nil when the model offers no prompt cache.
  Snapshot = Data.define(:date, :input, :output, :cached)

  # Minimal provider shape so the shared `provider_square` helper (which reads
  # name/slug/accent) works against catalog entries without an AiModel.
  ProviderRef = Data.define(:name, :slug, :accent)

  # One listed model with its current prices, context, tier, provider, and
  # full price history. Self-contained: `as_of` answers historical prices so
  # the retrospective can be computed without going back to the catalog.
  class Entry
    attr_reader :slug, :name, :tier, :context_window, :released_on, :status,
                :provider_name, :provider_slug, :provider_accent, :snapshots

    def initialize(model)
      @slug           = model.slug
      @name           = model.name
      @tier           = model.tier
      @context_window = model.context_window
      @released_on    = model.released_on
      @status         = model.status
      @provider_name  = model.provider.name
      @provider_slug  = model.provider.slug
      @provider_accent = model.provider.accent
      @snapshots = model.price_points.sort_by(&:effective_on).map do |pp|
        Snapshot.new(
          date:   pp.effective_on,
          input:  pp.input_per_mtok.to_f,
          output: pp.output_per_mtok.to_f,
          cached: pp.cached_input_per_mtok&.to_f
        )
      end
    end

    # Convenience alias matching the design engine's `m.ctx`.
    def ctx = context_window

    def provider = ProviderRef.new(name: provider_name, slug: provider_slug, accent: provider_accent)

    def current = snapshots.last
    def input  = current&.input
    def output = current&.output
    def cached = current&.cached

    # The price snapshot in effect on `date` — the latest one on or before it,
    # or nil if the model had no price yet (it wasn't available then).
    def as_of(date)
      snapshots.select { |s| s.date <= date }.max_by(&:date)
    end
  end

  class << self
    # All listed models (excludes retired + price-less), eager-loaded once.
    def models
      AiModel.listed.includes(:provider, :price_points).map { |m| Entry.new(m) }
    end

    def model(slug)
      models.find { |e| e.slug == slug }
    end

    # Chronological price history for one model.
    def history(slug)
      model(slug)&.snapshots || []
    end

    # The price snapshot for one model on a given date (latest on or before).
    def as_of(slug, date)
      model(slug)&.as_of(date)
    end

    # Every distinct price-change date across the whole catalog, ascending —
    # the x-axis for the "priced through history" retrospective.
    def change_dates
      models.flat_map { |e| e.snapshots.map(&:date) }.uniq.sort
    end

    # A sensible default "compare against" baseline: a recognizable premium model
    # if one is listed, otherwise the priciest frontier model — so the estimator
    # opens on a meaningful cheapest-equivalent savings story regardless of which
    # exact slugs the catalog carries.
    PREFERRED_BASELINES = %w[gpt-5 gpt-4o gpt-4-1 claude-opus-4-8 claude-sonnet-4-5 gemini-2-5-pro].freeze

    def default_baseline_slug
      all = models
      by_slug = all.index_by(&:slug)
      PREFERRED_BASELINES.find { |s| by_slug.key?(s) } ||
        all.select { |m| m.tier == "frontier" }.max_by { |m| (m.input || 0) + (m.output || 0) }&.slug ||
        all.first&.slug
    end
  end
end
