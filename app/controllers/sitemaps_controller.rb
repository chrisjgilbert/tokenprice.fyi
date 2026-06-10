class SitemapsController < ApplicationController
  def index
    @models = AiModel.listed.includes(:provider)
    @providers = Provider.all
    render formats: :xml
  end
end
