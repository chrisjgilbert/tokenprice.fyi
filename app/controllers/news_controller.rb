class NewsController < ApplicationController
  # How many items a page holds. A direct hit renders everything up to and
  # including the requested page (cumulative), so the standalone page stays
  # coherent without JS; "Load more" bumps the page.
  PER_PAGE = 30

  def index
    @page = [ params[:page].to_i, 1 ].max

    # Freshness rides the news table's latest write (an item is touched when it's
    # classified or attached to an event), not the price catalog. The page varies
    # by page number, so that rides the etag too.
    return if catalog_fresh?(etag: [ :news, @page ],
      last_modified: NewsItem.maximum(:updated_at))

    scope        = NewsItem.feed.includes(:market_event)
    @total       = scope.count
    @items       = scope.limit(@page * PER_PAGE).to_a
    @has_more    = @total > @items.size
    @next_page   = @page + 1
    @items_by_day = @items.group_by { |item| item.published_at.to_date }
  end
end
