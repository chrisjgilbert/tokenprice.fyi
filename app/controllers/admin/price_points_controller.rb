module Admin
  class PricePointsController < BaseController
    before_action :set_model
    before_action :set_price_point, only: %i[edit update destroy]

    def new
      @price_point = @model.price_points.new(effective_on: Date.current)
    end

    def create
      @price_point = @model.price_points.new(price_point_params)
      if @price_point.save
        redirect_to edit_admin_model_path(@model),
                    notice: "Added #{@model.name} price for #{@price_point.effective_on.strftime('%-d %b %Y')}."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @price_point.update(price_point_params)
        redirect_to edit_admin_model_path(@model), notice: "Updated price."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @price_point.destroy
      redirect_to edit_admin_model_path(@model), notice: "Deleted price snapshot.", status: :see_other
    end

    private

    def set_model
      @model = AiModel.find_by!(slug: params[:model_id])
    end

    def set_price_point
      @price_point = @model.price_points.find(params[:id])
    end

    def price_point_params
      params.require(:price_point).permit(
        :effective_on, :input_per_mtok, :output_per_mtok,
        :cached_input_per_mtok, :cache_write_per_mtok, :audio_input_per_mtok,
        :image_input_usd, :request_usd, :source, :note
      )
    end
  end
end
