module Admin
  class MarketEventInsightsController < BaseController
    # Regenerating runs a web search, which is too slow to block the request on,
    # so it goes to the queue and the admin refreshes to see the result.
    def create
      event = MarketEvent.find(params[:market_event_id])
      MarketEventInsightJob.perform_later(event)
      redirect_to admin_market_events_path,
                  notice: "Regenerating the “so what” for “#{event.title}” — refresh in a moment."
    end
  end
end
