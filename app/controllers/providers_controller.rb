class ProvidersController < ApplicationController
  SORTS = {
    "name"     => ->(m) { m.name.to_s.downcase },
    "tier"     => ->(m) { { "frontier" => 0, "mid" => 1, "small" => 2 }.fetch(m.tier, 3) },
    "input"    => ->(m) { m.current_input  || Float::INFINITY },
    "output"   => ->(m) { m.current_output || Float::INFINITY },
    "context"  => ->(m) { m.context_window || 0 },
    "released" => ->(m) { m.released_on || Date.new(1900, 1, 1) }
  }.freeze

  def show
    @provider = Provider.find_by!(slug: params[:id])

    @sort = params[:sort].presence_in(SORTS.keys) || "released"
    @dir  = params[:dir] == "asc" ? "asc" : "desc"

    models = @provider.ai_models.includes(:price_points).to_a
    models.sort_by!(&SORTS.fetch(@sort))
    models.reverse! if @dir == "desc"
    @models = models
  end
end
