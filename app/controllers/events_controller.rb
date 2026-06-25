class EventsController < ApplicationController
  def index
    # The timeline is driven by two sources — price-row writes (which back the
    # launch entries) and the curated market events — so revalidate on whichever
    # changed most recently, not just the price catalog.
    last_modified = [ PriceCatalog.last_modified, MarketEvent.maximum(:updated_at) ].compact.max
    return if catalog_fresh?(etag: [ :events ], last_modified: last_modified)

    @events = helpers.build_all_events
    @events_by_year = helpers.events_by_year(@events)
    @market_count = @events.count { |e| e.kind == "market" }
    @launch_count = @events.count { |e| e.kind == "launch" }
    # @events is sorted ascending, so the first entry is the earliest on record.
    @earliest_year = @events.first&.date&.year
  end
end
