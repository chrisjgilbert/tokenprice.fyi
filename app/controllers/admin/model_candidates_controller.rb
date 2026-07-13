module Admin
  # Review queue for model candidates the ModelCurationJob extracted from launch
  # news. Approving creates the real AiModel row (source: manual) — the same
  # write-path as admin/models — and reminds the reviewer to backfill db/seeds.rb,
  # the source of truth. Nothing here publishes without a click.
  class ModelCandidatesController < BaseController
    before_action :set_candidate, only: %i[accept dismiss]

    def index
      @pending = ModelCandidate.pending.recent_first
      @history = ModelCandidate.where.not(status: "pending").recent_first.limit(50)
    end

    def accept
      model = @candidate.accept!
      redirect_to admin_model_candidates_path,
                  notice: "Added “#{model.name}”. Backfill db/seeds.rb + the pricing doc to keep it durable."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_model_candidates_path, alert: "Couldn't add “#{@candidate.name}”: #{e.message}"
    end

    def dismiss
      @candidate.dismiss!
      redirect_to admin_model_candidates_path, notice: "Dismissed “#{@candidate.name}”."
    end

    private

    def set_candidate
      @candidate = ModelCandidate.find(params[:id])
    end
  end
end
