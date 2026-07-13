# The single read interface for price data. The estimator, the model-page
# embed, the education widgets, and the public JSON API all read prices
# *through here* — never via ad hoc AiModel queries — so the future
# measure-&-optimize product stays cleanly separable and can later swap or
# extend data sources without touching its consumers. Backed by AiModel today.
#
# Everything is exposed as small value objects (Entry / Snapshot) rather than
# ActiveRecord, so consumers depend on the interface, not the table.
class PriceCatalog
  # A single dated price observation. `input`/`output`/`cached`/`cache_write`/
  # `audio_input` are USD per 1M tokens; `image_input` is flat USD per input
  # image and `request` is flat USD per request. Each extra dimension is nil when
  # the model isn't charged for it (the `cached` precedent).
  Snapshot = Data.define(:date, :input, :output, :cached,
                         :cache_write, :audio_input, :image_input, :request)

  # Minimal provider shape so the shared `provider_square` helper (which reads
  # name/slug/accent) works against catalog entries without an AiModel.
  ProviderRef = Data.define(:name, :slug, :accent)

  # One listed model with its current prices, context, provider, and
  # full price history. Self-contained: `as_of` answers historical prices so
  # the retrospective can be computed without going back to the catalog.
  class Entry
    attr_reader :slug, :name, :context_window, :released_on, :status,
                :provider_name, :provider_slug, :provider_accent, :snapshots,
                :input_modalities, :output_modalities, :modality_class,
                :pricing_model, :price_summary, :price_detail, :price_source, :priced_as_of,
                :native_price_usd, :native_price_unit, :price_headline

    def initialize(model)
      @slug           = model.slug
      @name           = model.name
      @context_window = model.context_window
      @released_on    = model.released_on
      @status         = model.status
      @input_modalities  = model.input_modalities
      @output_modalities = model.output_modalities
      @modality_class    = model.modality_class
      @pricing_model  = model.pricing_model
      @price_summary  = model.price_summary
      @price_detail   = model.price_detail
      @price_source   = model.price_source
      @priced_as_of   = model.priced_as_of
      @native_price_usd  = model.native_price_usd&.to_f
      @native_price_unit = model.native_price_unit
      @price_headline    = model.price_headline
      @provider_name  = model.provider.name
      @provider_slug  = model.provider.slug
      @provider_accent = model.provider.accent
      @snapshots = model.price_points.sort_by(&:effective_on).map do |pp|
        Snapshot.new(
          date:         pp.effective_on,
          input:        pp.input_per_mtok&.to_f,
          output:       pp.output_per_mtok&.to_f,
          cached:       pp.cached_input_per_mtok&.to_f,
          cache_write:  pp.cache_write_per_mtok&.to_f,
          audio_input:  pp.audio_input_per_mtok&.to_f,
          image_input:  pp.image_input_usd&.to_f,
          request:      pp.request_usd&.to_f
        )
      end
    end

    # Convenience alias matching the design engine's `m.ctx`.
    def ctx = context_window

    def provider = ProviderRef.new(name: provider_name, slug: provider_slug, accent: provider_accent)

    def current = snapshots.last
    # A directory class whose price we've curated outside the per-token table:
    # a native-unit string (per image, credits, …) or a numeric single-unit rate
    # (speech-to-text's per-minute `native_price_usd`). Lockstep with AiModel.
    def native_priced? = price_summary.present? || native_price_usd.present?
    # Listed but not priced at all — a directory class with neither a price
    # snapshot nor a curated native price. Consumers show "not yet tracked".
    # Kept in lockstep with AiModel#directory_listing?.
    def directory_listing? = ModalityClass.directory_class?(modality_class) && current.nil? && !native_priced?
    def input  = current&.input
    def output = current&.output
    def cached = current&.cached
    def cache_write = current&.cache_write
    def audio_input = current&.audio_input
    def image_input = current&.image_input
    def request     = current&.request

    # The non-text billing dimensions beyond the three per-token rates, named once
    # so the model page and the admin history don't drift. Each carries its label,
    # unit suffix, and display precision: the raw-USD per-image / per-request fees
    # need 6 dp, the per-1M rates 4.
    BillingDimension = Data.define(:reader, :label, :unit, :decimals)
    EXTRA_DIMENSIONS = [
      BillingDimension.new(:cache_write, "Cache write", "/ 1M",    4),
      BillingDimension.new(:audio_input, "Audio input", "/ 1M",    4),
      BillingDimension.new(:image_input, "Image input", "/ image", 6),
      BillingDimension.new(:request,     "Per request", nil,       6)
    ].freeze

    BillingLine = Data.define(:label, :value, :unit, :decimals)

    # The dimensions this model is actually charged for. A stored 0 reads as "not
    # charged" (the `cached` precedent), so it's filtered out — never rendered as
    # a misleading "$0" line.
    def extra_billing
      EXTRA_DIMENSIONS.filter_map do |d|
        value = public_send(d.reader)
        BillingLine.new(d.label, value, d.unit, d.decimals) if value&.nonzero?
      end
    end

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

    # Recent price steps across the listed catalog, newest first — the homepage
    # "recent price changes" strip. `within` bounds staleness so a quiet stretch
    # shows nothing rather than a month-old move; `limit` caps the strip. Only
    # models with a snapshot inside the window can have a move to show, so the
    # candidate set is narrowed in SQL first — the strip never loads the whole
    # catalog's price history just to surface a handful of moves.
    def recent_price_moves(limit: 6, within: 30.days)
      scope = AiModel.listed
      if within
        repriced = PricePoint.where(effective_on: (Date.current - within)..).select(:ai_model_id)
        scope = scope.where(id: repriced)
      end
      scope.includes(:provider, :price_points)
        .filter_map { |m| m.latest_move(within: within) }
        .sort_by(&:effective_on).reverse.first(limit)
    end

    # A recognizable premium model to anchor the education pages' worked examples
    # on — the same baseline the estimator opens against. Pass `among:` to reuse an
    # already-loaded catalog and avoid a second `models` load. Nil on an empty catalog.
    def baseline(among: nil)
      all = among || models
      all.find { |e| e.slug == default_baseline_slug(all) }
    end

    # The catalog's freshness timestamp for conditional GET (Last-Modified /
    # ETag) on list pages: the most recent price-row write across the whole
    # catalog. A single aggregate query — does NOT load every entry. nil when
    # there are no price points yet (controllers fall back gracefully).
    def last_modified
      PricePoint.maximum(:updated_at)
    end

    # ISO 8601 date string of the most recent price-row write, for sitemap
    # lastmod. Falls back to today when no price points exist yet.
    def last_modified_date
      (last_modified || Date.current).strftime("%Y-%m-%d")
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
    # if one is listed, otherwise the priciest model by combined input+output — so
    # the estimator opens on a meaningful cheapest-equivalent savings story
    # regardless of which exact slugs the catalog carries.
    PREFERRED_BASELINES = %w[gpt-5 gpt-4o gpt-4-1 claude-opus-4-8 claude-sonnet-4-5 gemini-2-5-pro].freeze

    def default_baseline_slug(all = models)
      by_slug = all.index_by(&:slug)
      PREFERRED_BASELINES.find { |s| by_slug.key?(s) } ||
        all.max_by { |m| (m.input || 0) + (m.output || 0) }&.slug ||
        all.first&.slug
    end
  end
end
