class NewsController < ApplicationController
  # How many items a page holds. A direct hit renders everything up to and
  # including the requested page (cumulative), so the standalone page stays
  # coherent without JS; "Load more" bumps the page.
  PER_PAGE = 30

  def index
    @page = [ params[:page].to_i, 1 ].max

    # Freshness rides the news table's latest write AND the market-events table:
    # an item's "In Events" link turns on when its event is published, which is a
    # write to market_events, not to the news_item. Keying on both means that
    # transition busts the cache instead of serving a stale 304. The page varies
    # by page number, so that rides the etag too.
    return if catalog_fresh?(etag: [ :news, @page ],
      last_modified: [ NewsItem.maximum(:updated_at), MarketEvent.maximum(:updated_at) ].compact.max)

    # Fetch one past the page window so has_more needs no separate COUNT.
    window = @page * PER_PAGE
    rows   = NewsItem.feed.includes(:market_event).limit(window + 1).to_a
    @has_more = rows.size > window
    @items = rows.first(window)
    @items_by_day = @items.group_by { |item| item.published_at.to_date }
  end
end
