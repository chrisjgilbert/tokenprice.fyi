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

    # Compact payload the Stimulus controller reads to render the hover card.
    @countries_json = @countries.to_h { |c| [ c[:code], hover_card(c) ] }.to_json
  end

  private

  def build_country(code, provs)
    models   = provs.flat_map { |p| listed_models(p) }
    blendeds = models.filter_map(&:blended_per_mtok)
    cheapest = models.select { |m| m.blended_per_mtok }.min_by(&:blended_per_mtok)

    {
      code:           code,
      name:           provs.map(&:country).compact.first || code,
      flag:           provs.first.flag_emoji,
      providers:      provs,
      slugs:          provs.map(&:slug),
      href:           root_path(providers: provs.map(&:slug)),
      provider_count: provs.size,
      models:         models,
      model_count:    models.size,
      frontier_count: models.count { |m| m.tier == "frontier" },
      median_blended: median(blendeds),
      cheapest:       cheapest
    }
  end

  # The hover-card fields, pre-formatted so the JS just slots them in.
  def hover_card(c)
    {
      name:     c[:name],
      flag:     c[:flag],
      href:     c[:href],
      providers: c[:provider_count],
      models:   c[:model_count],
      frontier: c[:frontier_count],
      median:   c[:median_blended] ? helpers.usd_plain(c[:median_blended]) : "—",
      cheapest: c[:cheapest] && {
        io: "#{helpers.usd_plain(c[:cheapest].current_input)} / #{helpers.usd_plain(c[:cheapest].current_output)}"
      }
    }
  end

  # Median blended price — more representative than the mean, which a country
  # with many cheap small models would drag down.
  def median(values)
    return nil if values.empty?

    sorted = values.sort
    mid = sorted.size / 2
    sorted.size.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2
  end

  # Mirror AiModel.listed in memory so the eager-loaded associations aren't
  # defeated by a fresh query: not retired, and has at least one price point.
  def listed_models(provider)
    provider.ai_models.select { |m| m.status != "retired" && m.price_points.any? }
  end
end
