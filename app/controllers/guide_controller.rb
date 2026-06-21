# The Guide: a browse-by-task model picker. The index is the task chooser; each
# show page is one FeaturePattern's per-step pipeline. Both render from the
# FeaturePattern registry (DB-free editorial curation); show 404s for an
# unknown task the same way the rest of the app surfaces a missing record.
class GuideController < ApplicationController
  def index
    @patterns = FeaturePattern.all
  end

  def show
    @pattern = FeaturePattern.find(params[:task])
    return head :not_found unless @pattern
  end
end
