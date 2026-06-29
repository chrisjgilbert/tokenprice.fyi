class ModelsController < ApplicationController
  SORTS = {
    "input" => ->(m) { m.current_input || Float::INFINITY },
    "output" => ->(m) { m.current_output || Float::INFINITY },
    "cached" => ->(m) { m.current_cached_input || Float::INFINITY },
    "change" => ->(m) { m.input_change_since_launch || 0 },
    "context" => ->(m) { m.context_window || 0 },
    "name" => ->(m) { m.name.to_s.downcase },
    "tier" => ->(m) { { "frontier" => 0, "mid" => 1, "small" => 2 }.fetch(m.tier, 3) }
  }.freeze

  # Price-based sorts that a price-less row must always sink to the bottom of —
  # regardless of direction, so it never floats above a priced row when the list
  # is reversed. Name/tier/context/change still sort it normally: it has those.
  PRICE_SORTS = %w[input output cached].freeze

  # Most expensive output first. The view omits these from filter URLs to keep
  # them clean, so it reads the same constants rather than repeating the literals.
  DEFAULT_SORT = "output"
  DEFAULT_DIR  = "desc"

  def index
    @providers = Provider.order(:name).to_a

    scope = AiModel.listed.includes(:provider, :price_points)

    @tier = params[:tier].presence_in(AiModel.tiers.keys)
    scope = scope.where(tier: @tier) if @tier

    @provider_slugs = Array(params[:providers]).map(&:to_s) & @providers.map(&:slug)
    scope = scope.where(provider: @providers.select { |p| p.slug.in?(@provider_slugs) }) if @provider_slugs.any?

    @sort = params[:sort].presence_in(SORTS.keys) || DEFAULT_SORT
    @dir = params[:dir].presence_in(%w[asc desc]) || DEFAULT_DIR

    # Capped so a pathological query can't burn CPU in the fuzzy matcher.
    @query = params[:q].to_s.strip[0, 100]

    # modality_class is derived in Ruby, not a column. Validate the param against
    # the full known class set (no query) so it can ride the etag; the facet of
    # classes actually present is derived from the loaded rows after the 304
    # check, so a conditional hit pays for no extra load.
    @modality = params[:modality].presence_in(ModalityClass::LABELS.keys.map(&:to_s))

    # Conditional GET. The page varies by every filter/sort param, so they MUST
    # ride in the etag — otherwise a conditional request for one filtered view
    # would 304 off a different view's cache. Renders 304 and halts on a match.
    # last_modified spans the catalog AND the market events + model rows the hero
    # renders (helpers.build_all_events), so editing a market event or a model
    # busts the cache instead of serving a stale hero. Renders 304 on a match.
    return if catalog_fresh?(etag: [ :index, @tier, @provider_slugs.sort, @sort, @dir, @query, @modality ],
      last_modified: helpers.timeline_last_modified)

    models = scope.to_a
    if @query.match?(/[a-z0-9]/i)
      if @query.include?(",")
        segments = @query.split(",").map(&:strip).select { |s| s.match?(/[a-z0-9]/i) }
        models.select! { |m| segments.any? { |seg| m.matches?(seg) } } if segments.any?
      else
        models.select! { |m| m.matches?(@query) }
      end
    end
    # Facet options: the classes present among the rows the other filters left,
    # so no pill leads to an empty table. Derived before the modality filter is
    # applied so switching between classes stays possible.
    @modality_classes = models.map { |m| m.modality_class.to_s }.uniq.sort
    models.select! { |m| m.modality_class.to_s == @modality } if @modality
    @models = AiModel.sort_for_display(models, by: SORTS.fetch(@sort), dir: @dir,
      price_sort: PRICE_SORTS.include?(@sort))

    # Hero content (loaded once; lives outside the Turbo Frame).
    # Only loaded on full-page renders, not on Turbo Frame refreshes.
    unless request.headers["Turbo-Frame"] == "models"
      @all_events = helpers.build_all_events
      @all_models_count = AiModel.listed.count
      @providers_count = Provider.count
    end
  end

  def show
    @model = AiModel.includes(:provider, :price_points).find_by!(slug: params[:id])

    # Conditional GET keyed on this model's latest price write (updated_at, not
    # effective_on) so a same-day in-place price correction still busts the cache,
    # AND on the model row's own updated_at so an edit to non-price fields the page
    # renders (the modality signature, description, …) busts it too. Both ride the
    # ETag, so an If-None-Match alone invalidates.
    price_updated_at = @model.current_price&.updated_at
    freshness = [ price_updated_at, @model.updated_at ].compact.max
    return if catalog_fresh?(etag: [ :model_show, @model.slug, price_updated_at, @model.updated_at ],
      last_modified: freshness)

    @price_points = @model.price_points.chronological.to_a
    # Present when the model is listed — priced models and price-less Phase 2
    # directory rows alike (the latter render their prices as "not yet tracked").
    @catalog_entry = PriceCatalog.model(@model.slug)
    @related = AiModel.listed.where(provider: @model.provider)
      .where.not(id: @model.id)
      .includes(:price_points, :provider).by_release.limit(4)
  end
end
