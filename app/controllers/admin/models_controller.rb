module Admin
  class ModelsController < BaseController
    before_action :set_model, only: %i[edit update destroy]

    def index
      @models = AiModel.includes(:provider, :price_points)
                       .order(:provider_id, :name)
    end

    def new
      @model = AiModel.new(status: "active", tier: "frontier")
    end

    def create
      @model = AiModel.new(model_params)
      if @model.save
        redirect_to admin_models_path, notice: "Created #{@model.name}."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @model.update(model_params)
        redirect_to admin_models_path, notice: "Updated #{@model.name}."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @model.destroy
      redirect_to admin_models_path, notice: "Deleted #{@model.name}.", status: :see_other
    end

    private

    def set_model
      @model = AiModel.find_by!(slug: params[:id])
    end

    def model_params
      params.require(:ai_model).permit(
        :provider_id, :name, :slug, :tier, :status,
        :context_window, :max_output_tokens, :released_on, :description
      )
    end
  end
end
