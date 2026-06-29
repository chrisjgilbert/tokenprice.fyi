class SitemapsController < ApplicationController
  def index
    @models = AiModel.listed.includes(:provider)
    @providers = Provider.all
    @catalog_date = PriceCatalog.last_modified&.strftime("%Y-%m-%d") || Date.today.iso8601
    render formats: :xml
  end
end
