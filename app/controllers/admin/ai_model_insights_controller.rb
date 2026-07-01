module Admin
  class AiModelInsightsController < BaseController
    # Regenerating is an API call, too slow to block the request on, so it goes
    # to the queue and the admin refreshes to see the result.
    def create
      model = AiModel.find_by!(slug: params[:model_id])
      AiModelInsightJob.perform_later(model)
      redirect_to edit_admin_model_path(model),
                  notice: "Regenerating the “so what” for “#{model.name}” — refresh in a moment."
    end
  end
end
