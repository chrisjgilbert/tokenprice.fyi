module Admin
  class ProvidersController < BaseController
    before_action :set_provider, only: %i[edit update destroy]

    def index
      @providers = Provider.order(:name)
    end

    def new
      @provider = Provider.new
    end

    def create
      @provider = Provider.new(provider_params)
      if @provider.save
        redirect_to admin_providers_path, notice: "Created #{@provider.name}."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @provider.update(provider_params)
        redirect_to admin_providers_path, notice: "Updated #{@provider.name}."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @provider.ai_models.exists?
        redirect_to admin_providers_path, alert: "Remove its models first.", status: :see_other
      else
        @provider.destroy
        redirect_to admin_providers_path, notice: "Deleted #{@provider.name}.", status: :see_other
      end
    end

    private

    def set_provider
      @provider = Provider.find_by!(slug: params[:id])
    end

    def provider_params
      params.require(:provider).permit(:name, :slug, :website, :accent)
    end
  end
end
