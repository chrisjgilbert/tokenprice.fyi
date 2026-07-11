class NewsController < ApplicationController
  # How many items a page holds. A direct hit renders everything up to and
  # including the requested page (cumulative), so the standalone page stays
  # coherent without JS; "Load more" bumps the page.
  PER_PAGE = 30

  def index
    @page = [ params[:page].to_i, 1 ].max

    # Freshness rides three tables: the news table's latest write; the
    # market-events table (an item's "In Events" link turns on when its event is
    # published — a market_events write, not a news_item one); and the price rows
    # behind the recent-changes strip (PriceCatalog.last_modified). Any of those
    # transitions busts the cache instead of serving a stale 304. The page varies
    # by page number, so that rides the etag too.
    return if catalog_fresh?(etag: [ :news, @page ],
      last_modified: [ NewsItem.maximum(:updated_at), MarketEvent.maximum(:updated_at),
                       PriceCatalog.last_modified ].compact.max)

    @recent_price_moves = PriceCatalog.recent_price_moves

    # Fetch one past the page window so has_more needs no separate COUNT.
    window = @page * PER_PAGE
    rows   = NewsItem.feed.includes(:market_event).limit(window + 1).to_a
    @has_more = rows.size > window
    @items = rows.first(window)
    @items_by_day = @items.group_by { |item| item.published_at.to_date }
  end
end
