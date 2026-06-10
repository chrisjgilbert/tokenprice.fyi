class TrendsController < ApplicationController
  def index
    @year = Date.current.year

    # Cheapest → priciest frontier models, by blended price.
    @frontier_ranked = AiModel.listed.frontier.includes(:provider, :price_points).to_a
                              .sort_by { |m| m.blended_per_mtok || Float::INFINITY }

    # Models whose price has actually moved (more than one snapshot).
    @movers = AiModel.includes(:provider, :price_points).to_a
                     .select(&:price_changed?)
                     .sort_by { |m| m.blended_change_since_launch || 0 }

    # Release timeline for the current year.
    @timeline = AiModel.includes(:provider)
                       .where(released_on: Date.new(@year, 1, 1)..Date.new(@year, 12, 31))
                       .order(released_on: :asc).to_a
  end
end
