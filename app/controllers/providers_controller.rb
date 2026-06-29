class ProvidersController < ApplicationController
  SORTS = {
    "name"     => ->(m) { m.name.to_s.downcase },
    "tier"     => ->(m) { { "frontier" => 0, "mid" => 1, "small" => 2 }.fetch(m.tier, 3) },
    "input"    => ->(m) { m.current_input  || Float::INFINITY },
    "output"   => ->(m) { m.current_output || Float::INFINITY },
    "context"  => ->(m) { m.context_window || 0 },
    "released" => ->(m) { m.released_on || Date.new(1900, 1, 1) }
  }.freeze

  # Price sorts a price-less row must always sink below, in either direction
  # (see ModelsController::PRICE_SORTS for the rationale).
  PRICE_SORTS = %w[input output].freeze

  def show
    @provider = Provider.find_by!(slug: params[:id])

    @sort = params[:sort].presence_in(SORTS.keys) || "released"
    @dir  = params[:dir] == "asc" ? "asc" : "desc"

    # Conditional GET. The listing varies by ?sort=/?dir=, so both ride in the
    # etag to keep a sorted view from 304ing off a differently-sorted one.
    return if catalog_fresh?(etag: [ :provider_show, @provider.slug, @sort, @dir ])

    models = @provider.ai_models.includes(:price_points).to_a
    @models = AiModel.sort_for_display(models, by: SORTS.fetch(@sort), dir: @dir,
      price_sort: PRICE_SORTS.include?(@sort))
  end
end
