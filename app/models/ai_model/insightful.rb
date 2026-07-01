# Facade for generating a launch's "so what". Reached as ai_model.generate_insight;
# delegates to the AiModel::Insight operation and persists the result. The
# injected client keeps it testable without an API.
module AiModel::Insightful
  def generate_insight(client: nil)
    result = AiModel::Insight.new(self, client: client).run
    update!(so_what: result[:so_what], so_what_generated_at: Time.current)
  end
end
