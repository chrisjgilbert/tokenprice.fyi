class ModelsController < ApplicationController
  SORTS = {
    "blended"  => ->(m) { m.blended_per_mtok || Float::INFINITY },
    "input"    => ->(m) { m.current_input  || Float::INFINITY },
    "output"   => ->(m) { m.current_output || Float::INFINITY },
    "context"  => ->(m) { m.context_window || 0 },
    "released" => ->(m) { m.released_on || Date.new(1900, 1, 1) },
    "name"     => ->(m) { m.name.to_s.downcase }
  }.freeze

  def index
    @providers = Provider.order(:name).to_a

    scope = AiModel.listed.includes(:provider, :price_points)

    @tier = params[:tier].presence_in(AiModel.tiers.keys)
    scope = scope.where(tier: @tier) if @tier

    @provider_slugs = Array(params[:providers]).map(&:to_s) & @providers.map(&:slug)
    scope = scope.where(provider: @providers.select { |p| p.slug.in?(@provider_slugs) }) if @provider_slugs.any?

    @sort = params[:sort].presence_in(SORTS.keys) || "blended"
    @dir  = params[:dir] == "desc" ? "desc" : "asc"

    @query = params[:q].to_s.strip

    models = scope.to_a
    models.select! { |m| m.matches?(@query) } if @query.present?
    models.sort_by!(&SORTS.fetch(@sort))
    models.reverse! if @dir == "desc"
    @models = models

    # Headline stat: cheapest frontier model by blended price.
    @cheapest_frontier = AiModel.listed.frontier.includes(:price_points, :provider)
                                .min_by { |m| m.blended_per_mtok || Float::INFINITY }
  end

  def show
    @model = AiModel.includes(:provider, :price_points).find_by!(slug: params[:id])
    @price_points = @model.price_points.chronological.to_a
    @related = AiModel.listed.where(provider: @model.provider)
                      .where.not(id: @model.id)
                      .includes(:price_points, :provider).by_release.limit(4)
  end
end
