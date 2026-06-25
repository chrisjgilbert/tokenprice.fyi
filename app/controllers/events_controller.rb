class EventsController < ApplicationController
  def index
    # Revalidate on the freshness of every source the timeline reads — prices,
    # market events, and the model/provider rows behind the launch entries —
    # shared with the homepage hero via this helper so the two can't drift.
    return if catalog_fresh?(etag: [ :events ], last_modified: helpers.timeline_last_modified)

    @events = helpers.build_all_events
    @events_by_year = helpers.events_by_year(@events)
    @market_count = @events.count { |e| e.kind == "market" }
    @launch_count = @events.count { |e| e.kind == "launch" }
    # @events is sorted ascending, so the first entry is the earliest on record.
    @earliest_year = @events.first&.date&.year
  end
end
