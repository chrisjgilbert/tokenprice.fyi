class TrendsController < ApplicationController
  def show
    # Both keys ride the etag itself (not just Last-Modified) because a matching
    # If-None-Match wins over If-Modified-Since, so a stale-but-matching etag would
    # 304 past a data edit: FlagshipTrend.last_modified busts on any price/model
    # write, and Date.current busts daily since the chart's right edge and year
    # ticks track today.
    stamp = FlagshipTrend.last_modified
    return if catalog_fresh?(etag: [ :trends, Date.current, stamp ], last_modified: stamp)

    @trends = FlagshipTrend.all
    @recent_price_moves = PriceCatalog.recent_price_moves
  end
end
