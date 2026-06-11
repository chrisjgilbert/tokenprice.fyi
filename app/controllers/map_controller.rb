class MapController < ApplicationController
  def index
    providers = Provider.includes(ai_models: :price_points).order(:name).to_a

    located = providers.select { |p| p.country_code.present? }

    @countries = located
      .group_by(&:country_code)
      .map { |code, provs| build_country(code, provs) }
      .sort_by { |c| [ -c[:provider_count], -c[:model_count], c[:name] ] }

    @by_code           = @countries.index_by { |c| c[:code] }
    @total_providers   = providers.size
    @located_providers = located.size
    @total_models      = @countries.sum { |c| c[:model_count] }
    @max_providers     = @countries.map { |c| c[:provider_count] }.max || 0
    @leader            = @countries.first
    @unlocated         = providers.reject { |p| p.country_code.present? }
  end

  private

  def build_country(code, provs)
    models = provs.flat_map { |p| listed_models(p) }
    cheapest = models.select { |m| m.blended_per_mtok }.min_by(&:blended_per_mtok)

    {
      code:           code,
      name:           provs.map(&:country).compact.first || code,
      providers:      provs,
      provider_count: provs.size,
      models:         models,
      model_count:    models.size,
      frontier_count: models.count { |m| m.tier == "frontier" },
      cheapest:       cheapest
    }
  end

  # Mirror AiModel.listed in memory so the eager-loaded associations aren't
  # defeated by a fresh query: not retired, and has at least one price point.
  def listed_models(provider)
    provider.ai_models.select { |m| m.status != "retired" && m.price_points.any? }
  end
end
