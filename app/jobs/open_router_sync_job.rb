# Pulls the OpenRouter model catalogue and prices once a day (see
# config/recurring.yml). All the work lives in OpenRouter::ModelSync; this is
# just the schedulable Active Job wrapper.
class OpenRouterSyncJob < ApplicationJob
  queue_as :default

  def perform
    OpenRouter::ModelSync.call
  end
end
