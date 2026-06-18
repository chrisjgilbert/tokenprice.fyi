# The model-page estimate embed: a compact mini-estimator pre-filled with the
# current model as the baseline, so the estimator rides the index's traffic.
# Uses the same CostEstimate engine, rendering its output into a per-model
# Turbo Frame; "Open in full estimator" deep-links to /cost with this model
# encoded as the baseline.
class EmbedsController < ApplicationController
  def show
    @entry = PriceCatalog.model(params[:id])
    return head :not_found unless @entry

    @in_pos  = (params[:in_pos]  || CostEstimate.embed_slider(1500)).to_i.clamp(0, 100)
    @out_pos = (params[:out_pos] || CostEstimate.embed_slider(600)).to_i.clamp(0, 100)
    @req     = (params[:req].presence || 100_000).to_i.clamp(1, 5_000_000_000)
    fresh    = CostEstimate.embed_tokens(@in_pos)
    out      = CostEstimate.embed_tokens(@out_pos)

    profile  = CostEstimate.profile_from(sys: 0, fresh: fresh, out: out, req: @req,
                                         cache: 0, tier: "any", base: @entry.slug)
    estimate = CostEstimate.new(profile, models: PriceCatalog.models)

    @here     = estimate.rows.find { |r| r.slug == @entry.slug }
    @cheapest = estimate.rows.find(&:fits?)
    @deep_link = cost_path(profile.to_query)

    render partial: "embeds/embed",
           locals: { entry: @entry, here: @here, cheapest: @cheapest, fresh: fresh, out: out,
                     req: @req, in_pos: @in_pos, out_pos: @out_pos, deep_link: @deep_link }
  end
end
