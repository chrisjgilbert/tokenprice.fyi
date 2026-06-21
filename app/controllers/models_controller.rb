class ModelsController < ApplicationController
  SORTS = {
    "blended"  => ->(m) { m.blended_per_mtok || Float::INFINITY },
    "change"   => ->(m) { m.blended_change_since_launch || 0 },
    "input"    => ->(m) { m.current_input  || Float::INFINITY },
    "output"   => ->(m) { m.current_output || Float::INFINITY },
    "cached"   => ->(m) { m.current_cached_input || Float::INFINITY },
    "context"  => ->(m) { m.context_window || 0 },
    "released" => ->(m) { m.released_on || Date.new(1900, 1, 1) },
    "name"     => ->(m) { m.name.to_s.downcase },
    "tier"     => ->(m) { { "frontier" => 0, "mid" => 1, "small" => 2 }.fetch(m.tier, 3) }
  }.freeze

  def index
    @providers = Provider.order(:name).to_a

    scope = AiModel.listed.includes(:provider, :price_points)

    @tier = params[:tier].presence_in(AiModel.tiers.keys)
    scope = scope.where(tier: @tier) if @tier

    @provider_slugs = Array(params[:providers]).map(&:to_s) & @providers.map(&:slug)
    scope = scope.where(provider: @providers.select { |p| p.slug.in?(@provider_slugs) }) if @provider_slugs.any?

    @sort = params[:sort].presence_in(SORTS.keys) || "blended"
    @dir  = params[:dir].presence_in(%w[asc desc]) || (@sort == "blended" ? "desc" : "asc")

    # Capped so a pathological query can't burn CPU in the fuzzy matcher.
    @query = params[:q].to_s.strip[0, 100]

    models = scope.to_a
    if @query.match?(/[a-z0-9]/i)
      if @query.include?(",")
        segments = @query.split(",").map(&:strip).select { |s| s.match?(/[a-z0-9]/i) }
        models.select! { |m| segments.any? { |seg| m.matches?(seg) } } if segments.any?
      else
        models.select! { |m| m.matches?(@query) }
      end
    end
    models.sort_by!(&SORTS.fetch(@sort))
    models.reverse! if @dir == "desc"
    @models = models

    # Headline stat: cheapest frontier model by blended price.
    @cheapest_frontier = AiModel.listed.frontier.includes(:price_points, :provider)
                                .min_by { |m| m.blended_per_mtok || Float::INFINITY }

    # Hero events timeline (loaded once; lives outside the Turbo Frame).
    # Only loaded on full-page renders, not on Turbo Frame refreshes.
    unless request.headers["Turbo-Frame"] == "models"
      @all_events = helpers.build_all_events
      @all_models_count = AiModel.listed.count
      @providers_count = Provider.count

      # The genuine minimum simple in+out average across the priced catalog,
      # so the "cheapest, in+out avg /1M" stat's value truly is the minimum its
      # label claims. nil when nothing is priced.
      @cheapest_io_avg = AiModel.listed.includes(:price_points)
                                .filter_map { |m|
                                  next unless m.current_input && m.current_output
                                  (m.current_input + m.current_output) / 2.0
                                }.min
    end
  end

  def show
    @model = AiModel.includes(:provider, :price_points).find_by!(slug: params[:id])
    @price_points = @model.price_points.chronological.to_a
    # Present only when the model is in the price catalog (listed + priced).
    @catalog_entry = PriceCatalog.model(@model.slug)
    @insights = ModelInsights.new(@model)
    @related = AiModel.listed.where(provider: @model.provider)
                      .where.not(id: @model.id)
                      .includes(:price_points, :provider).by_release.limit(4)
  end
end
