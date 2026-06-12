class PagesController < ApplicationController
  # The "why" thought piece is still a draft: kept in the codebase for
  # iteration, previewable when signed in as admin, invisible (404)
  # to the public.
  before_action :require_admin_preview, only: %i[why]

  def why
  end

  def which_model
  end

  def how_pricing_works
    @frontier_example = AiModel.listed.where(tier: "frontier")
                              .select(&:current_input)
                              .min_by(&:current_input)
  end

  private

  def require_admin_preview
    head :not_found unless session[:admin]
  end
end
