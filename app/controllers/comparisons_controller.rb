class ComparisonsController < ApplicationController
  # /compare?a=claude-opus-4-8&b=gpt-5-5  → side-by-side of two models.
  def show
    @all_models = AiModel.listed.includes(:provider, :price_points).by_release.to_a

    @left  = find_model(params[:a]) || default_left
    @right = find_model(params[:b]) || default_right(@left)
  end

  private

  def find_model(slug)
    return nil if slug.blank?

    @all_models.find { |m| m.slug == slug }
  end

  def default_left
    @all_models.find { |m| m.slug == "claude-opus-4-8" } || @all_models.first
  end

  def default_right(left)
    @all_models.find { |m| m.slug == "gpt-5-5" } ||
      @all_models.find { |m| m != left }
  end
end
