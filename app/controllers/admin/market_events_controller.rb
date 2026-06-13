module Admin
  class MarketEventsController < BaseController
    before_action :set_event, only: %i[edit update destroy publish]

    def index
      @drafts    = MarketEvent.drafts.recent_first
      @published = MarketEvent.published.recent_first
    end

    def new
      @event = MarketEvent.new(status: "published", kind: "market", source: "admin")
    end

    def create
      @event = MarketEvent.new(event_params)
      if @event.save
        redirect_to admin_market_events_path, notice: "Created event."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @event.update(event_params)
        redirect_to admin_market_events_path, notice: "Updated event."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      # Unlink news items so they can be re-proposed; mark them not re-draftable
      @event.news_items.update_all(market_event_id: nil, relevant: false)
      @event.destroy
      redirect_to admin_market_events_path, notice: "Discarded event.", status: :see_other
    end

    def publish
      @event.update!(status: "published")
      redirect_to admin_market_events_path, notice: "Published “#{@event.title}”."
    end

    private

    def set_event
      @event = MarketEvent.find(params[:id])
    end

    def event_params
      params.require(:market_event).permit(
        :title, :note, :event_date, :kind, :status, :source, :source_url
      )
    end
  end
end
