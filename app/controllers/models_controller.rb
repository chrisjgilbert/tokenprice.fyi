class ModelsController < ApplicationController
  def index
    models = AiModel.listed.includes(:provider, :price_points).to_a
                    .sort_by { |m| m.blended_per_mtok || Float::INFINITY }

    # Headline stat: cheapest frontier model by blended price.
    cheapest_frontier = models.find(&:frontier?)

    @page_title = "LLM API price tracker — tokenprice.fyi"
    @json_ld = {
      "@context": "https://schema.org",
      "@type": "ItemList",
      name: "LLM API pricing",
      itemListElement: models.each_with_index.map { |m, i|
        { "@type": "ListItem", position: i + 1, name: m.name, url: model_url(m) }
      }
    }

    render inertia: "Models/Index", props: {
      models: models.map { |m| grid_row(m) },
      cheapestFrontier: cheapest_frontier && grid_row(cheapest_frontier)
    }
  end

  def show
    @model = AiModel.includes(:provider, :price_points).find_by!(slug: params[:id])
    @price_points = @model.price_points.chronological.to_a
    @related = AiModel.listed.where(provider: @model.provider)
                      .where.not(id: @model.id)
                      .includes(:price_points, :provider).by_release.limit(4)
  end

  private

  # One AG Grid row. Decimals become floats so they serialize as JSON numbers.
  def grid_row(model)
    {
      name: model.name,
      url: model_path(model),
      provider: model.provider.name,
      providerUrl: provider_path(model.provider),
      tier: model.tier,
      status: model.status,
      input: model.current_input&.to_f,
      output: model.current_output&.to_f,
      cachedInput: model.current_cached_input&.to_f,
      contextWindow: model.context_window,
      blended: model.blended_per_mtok&.to_f,
      releasedOn: model.released_on&.iso8601
    }
  end
end
