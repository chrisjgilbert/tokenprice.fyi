class ProvidersController < ApplicationController
  def show
    @provider = Provider.find_by!(slug: params[:id])
    @models = @provider.ai_models.includes(:price_points).by_release.to_a
  end
end
