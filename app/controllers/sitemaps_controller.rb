class SitemapsController < ApplicationController
  def index
    @models = AiModel.listed.includes(:provider)
    @providers = Provider.all
    @catalog_date = PriceCatalog.last_modified_date
    render formats: :xml
  end
end
