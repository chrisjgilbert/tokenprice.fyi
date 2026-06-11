class PagesController < ApplicationController
  # The thought pieces are drafts for now: kept in the codebase for
  # iteration, previewable when signed in as admin, invisible (404)
  # to the public.
  before_action :require_admin_preview

  def why
  end

  def which_model
  end

  private

  def require_admin_preview
    head :not_found unless session[:admin]
  end
end
