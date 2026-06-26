# The Guide: a browse-by-task model picker. The index is the task chooser; each
# show page is one FeaturePattern's per-step pipeline. Both render from the
# FeaturePattern registry (DB-free editorial curation); show 404s for an
# unknown task the same way the rest of the app surfaces a missing record.
class GuideController < ApplicationController
  def index
    return if catalog_fresh?(etag: [ :guide_index ])

    @patterns = FeaturePattern.all
  end

  def show
    @pattern = FeaturePattern.find(params[:task])
    return head :not_found unless @pattern

    return if catalog_fresh?(etag: [ :guide_show, @pattern.key ])

    # Load the price catalog once for the whole page; each step prices its
    # options against this injected catalog instead of re-loading it.
    @catalog = PriceCatalog.models
  end
end
