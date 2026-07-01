# Generates the "so what" for a model's launch out of band. Non-fatal: a
# generation failure is logged, not raised, so a flaky API call doesn't poison
# the queue — the admin can retry from the edit page.
class AiModelInsightJob < ApplicationJob
  queue_as :default

  def perform(model)
    model.generate_insight
  rescue AiModel::Insight::Error, AnthropicClient::MissingApiKeyError => e
    Rails.logger.warn("AiModelInsightJob: #{e.message} (model ##{model.id})")
    Honeybadger.notify(e) if defined?(Honeybadger)
  end
end
