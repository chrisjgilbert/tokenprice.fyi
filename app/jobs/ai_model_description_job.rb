# Generates a model's editorial write-up out of band — description plus
# strengths / best-for / limitations. Non-fatal like AiModelInsightJob: a
# generation failure is logged, not raised, so a flaky API call doesn't poison
# the queue — the admin can retry from the edit page, and the model keeps its
# (blank) copy until then rather than the whole accept failing.
class AiModelDescriptionJob < ApplicationJob
  queue_as :default

  def perform(model)
    model.generate_description
  rescue AiModel::Description::GenerateError => e
    Rails.logger.warn("AiModelDescriptionJob: #{e.message} (model ##{model.id})")
    Honeybadger.notify(e) if defined?(Honeybadger)
  end
end
