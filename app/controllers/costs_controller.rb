# The single-workload estimator. Decodes the workload from query params (so any
# view is a shareable, indexable permalink), prices it across the catalog via
# CostEstimate, and renders the result into a Turbo Frame — frame-only on a
# frame request, exactly like ModelsController#index swaps #models.
class CostsController < ApplicationController
  WORKLOAD_KEYS = %i[sys fresh out req cache tier base summary].freeze

  def show
    # Describe-in-a-sentence on-ramp (heuristic only — no LLM on the critical
    # path). Fill a profile from the text, then redirect to the canonical param
    # URL so the fields and the permalink reflect it.
    if params[:describe].present? && !workload_params?
      query = CostEstimate.profile_from(CostEstimate.heuristic_fill(params[:describe])).to_query
      query.delete(:base) # let the catalog default baseline win, not the heuristic's mock slug
      redirect_to cost_path(query) and return
    end

    @models   = PriceCatalog.models
    # Default the baseline to a recognizable catalog model when none is given,
    # so the opening view shows a real cheapest-equivalent comparison.
    query = request.query_parameters
    query = query.merge("base" => PriceCatalog.default_baseline_slug(@models)) if query["base"].blank?

    @profile  = CostEstimate.profile_from(query)
    @estimate = CostEstimate.new(@profile, models: @models)
    @sort     = params[:sort].presence_in(%w[monthly call]) || "monthly"

    if request.headers["Turbo-Frame"] == "cost_result"
      render(partial: "costs/result", locals: { estimate: @estimate, profile: @profile, sort: @sort }) and return
    end
  end

  private

  def workload_params?
    (WORKLOAD_KEYS & request.query_parameters.keys.map(&:to_sym)).any?
  end
end
