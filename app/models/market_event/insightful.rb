# Facade for generating a market event's "so what". Reached as
# market_event.generate_insight; delegates to the MarketEvent::Insight operation
# and persists the result. The injected client keeps it testable without an API.
module MarketEvent::Insightful
  def generate_insight(client: nil)
    result = MarketEvent::Insight.new(self, client: client).run
    update!(
      so_what:              result[:so_what],
      citations:            result[:citations],
      so_what_generated_at: Time.current
    )
  end
end
