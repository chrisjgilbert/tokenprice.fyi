class EventsController < ApplicationController
  # How many timeline entries a page holds. The first page renders with the
  # document; later pages are appended as the sentinel scrolls into view.
  PER_PAGE = 20

  def index
    @kind = params[:kind].presence_in(%w[market launch])
    @page = [ params[:page].to_i, 1 ].max

    # The same URL serves a cumulative HTML page (a direct/no-JS hit) and a Turbo
    # Stream append (the infinite-scroll fetch), chosen by Accept. Vary on it so a
    # shared cache can't hand one representation to a request that wants the other.
    response.headers["Vary"] = [ response.headers["Vary"], "Accept" ].compact.join(", ")

    # Revalidate on the freshness of every source the timeline reads — prices,
    # market events, and the model/provider rows behind the launch entries —
    # shared with the homepage hero via this helper so the two can't drift. The
    # page varies by kind, page number, and response format (a full HTML page vs.
    # a Turbo Stream append), so all three ride the etag — otherwise one view
    # would 304 off another's cache.
    return if catalog_fresh?(etag: [ :events, @kind, @page, request.format.symbol ],
      last_modified: helpers.timeline_last_modified)

    all = helpers.build_all_events

    # The counts and earliest year drive the header and filter tabs, which only
    # the full HTML page renders — skip them on the Turbo Stream append path.
    unless request.format.turbo_stream?
      @total_count   = all.size
      @market_count  = all.count { |e| e.kind == "market" }
      @launch_count  = all.count { |e| e.kind == "launch" }
      # `all` is sorted ascending, so the first entry is the earliest on record.
      @earliest_year = all.first&.date&.year
    end

    # Newest first for display, filtered to the active kind.
    timeline = all.reverse
    timeline = timeline.select { |e| e.kind == @kind } if @kind
    @filtered_count = timeline.size

    # The Turbo Stream response appends only the requested page; a direct HTML
    # hit (no JS, or the "Load more" link) renders everything up to and including
    # the requested page so the standalone page stays coherent.
    upper = @page * PER_PAGE
    lower = request.format.turbo_stream? ? (@page - 1) * PER_PAGE : 0
    @events = timeline[lower...upper] || []
    @has_more  = upper < @filtered_count
    @next_page = @page + 1
    @events_by_year = helpers.events_by_year(@events)

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
end
