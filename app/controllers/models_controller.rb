class ModelsController < ApplicationController
  SORTS = {
    "input" => ->(m) { m.current_input || Float::INFINITY },
    "output" => ->(m) { m.current_output || Float::INFINITY },
    "cached" => ->(m) { m.current_cached_input || Float::INFINITY },
    "context" => ->(m) { m.context_window || 0 },
    "name" => ->(m) { m.name.to_s.downcase },
    "tier" => ->(m) { { "frontier" => 0, "mid" => 1, "small" => 2 }.fetch(m.tier, 3) },
    # Image-category sorts: it has no per-token axis, so it ranks by provider and
    # release date instead. A nil release sorts oldest rather than to the top.
    "provider" => ->(m) { m.provider.name.to_s.downcase },
    "released" => ->(m) { m.released_on || Date.new(1970, 1, 1) },
    # Speech-to-text ranks on its numeric native per-minute rate. A row without
    # one sinks to the bottom (it can't be ranked on this axis); it's kept out of
    # PRICE_SORTS because those partition on `token_priced?`, which no native row
    # is — that would sink every speech row instead of sorting them.
    "native_price" => ->(m) { m.native_price_usd || Float::INFINITY }
  }.freeze

  # Price-based sorts that a price-less row must always sink to the bottom of —
  # regardless of direction, so it never floats above a priced row when the list
  # is reversed. Name/tier/context still sort it normally: it has those.
  PRICE_SORTS = %w[input output cached].freeze

  def index
    @providers = Provider.order(:name).to_a

    # The pricing-family tab. Every param the category governs (sort keys,
    # defaults, SEO) is read off it, so a new tab is a registry + route change.
    @category = ModelCategory.for(params[:category])

    scope = AiModel.listed.includes(:provider, :price_points)

    @tiers = Array(params[:tier]).map(&:to_s) & AiModel.tiers.keys
    scope = scope.where(tier: @tiers) if @tiers.any?

    @provider_slugs = Array(params[:providers]).map(&:to_s) & @providers.map(&:slug)
    scope = scope.where(provider: @providers.select { |p| p.slug.in?(@provider_slugs) }) if @provider_slugs.any?

    @sort = params[:sort].presence_in(@category.sorts) || @category.default_sort
    @dir = params[:dir].presence_in(%w[asc desc]) || @category.default_dir

    # Capped so a pathological query can't burn CPU in the fuzzy matcher.
    @query = params[:q].to_s.strip[0, 100]

    # modality_class is derived in Ruby, not a column. Validate the param against
    # the full known class set (no query) so it can ride the etag; the facet of
    # classes actually present is derived from the loaded rows after the 304
    # check, so a conditional hit pays for no extra load.
    # Scope the modality facet to classes that belong to THIS tab, so a stale
    # inbound link like /?modality=image_generation (image moved to its own tab)
    # is ignored rather than filtering the language rows down to an empty table.
    @modalities = (Array(params[:modality]).map(&:to_s) & ModalityClass::LABELS.keys.map(&:to_s))
      .select { |mc| @category.member?(mc.to_sym) }

    # Per-category SEO the view reads for <title>, meta description, and canonical
    # (the tab is an indexable URL, not a query permutation, so each owns its own).
    @page_title = @category.title
    @page_description = @category.meta_description
    @canonical_url = send("#{@category.path_name}_url")

    # Conditional GET. The page varies by every filter/sort param AND the category
    # tab, so they MUST ride in the etag — otherwise a conditional request for one
    # view would 304 off another's cache (a tab off a sibling tab included).
    # last_modified spans the catalog AND the market events + model rows the hero
    # renders (helpers.build_all_events), so editing a market event or a model
    # busts the cache instead of serving a stale hero. Renders 304 on a match.
    return if catalog_fresh?(etag: [ :index, @category.slug, @tiers.sort, @provider_slugs.sort, @sort, @dir, @query, @modalities.sort ],
      last_modified: helpers.timeline_last_modified)

    # Tab labels: how many listed models fall in each category. Classified via the
    # SAME derived modality_class the row filter uses (not the denormalised column),
    # so a badge count always equals its tab's row count. One light load, not a
    # query per tab.
    listed_classes = AiModel.listed.select(:input_modalities, :output_modalities).map(&:modality_class)
    @category_counts = ModelCategory.all.to_h { |category|
      [ category.slug, listed_classes.count { |mc| category.member?(mc) } ]
    }

    models = scope.to_a
    if @query.match?(/[a-z0-9]/i)
      if @query.include?(",")
        segments = @query.split(",").map(&:strip).select { |s| s.match?(/[a-z0-9]/i) }
        models.select! { |m| segments.any? { |seg| m.matches?(seg) } } if segments.any?
      else
        models.select! { |m| m.matches?(@query) }
      end
    end
    # Restrict to the current tab's pricing family before deriving facets, so both
    # the modality facet options and the row set reflect only this category.
    models.select! { |m| @category.member?(m.modality_class) }
    # Facet options: the classes present among the rows the other filters left,
    # so no pill leads to an empty table. Derived before the modality filter is
    # applied so switching between classes stays possible.
    @modality_classes = models.map { |m| m.modality_class.to_s }.uniq.sort
    models.select! { |m| @modalities.include?(m.modality_class.to_s) } if @modalities.any?
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

    # The freshness instant the page surfaces to readers — the same value the
    # conditional GET is keyed on, so "data updated" can't claim a time newer
    # than the one the cache would serve.
    @last_updated = freshness
    @price_points = @model.price_points.chronological.to_a
    # Present only when the model is listed (priced); nil otherwise, so the view's
    # extra-billing section reads off a real catalog entry or renders nothing.
    @catalog_entry = PriceCatalog.model(@model.slug)
    @related = AiModel.listed.where(provider: @model.provider)
      .where.not(id: @model.id)
      .includes(:price_points, :provider).by_release.limit(4)
  end
end
