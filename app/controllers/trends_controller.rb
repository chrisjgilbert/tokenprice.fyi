class TrendsController < ApplicationController
  def show
    # Both keys ride the etag itself (not just Last-Modified) because a matching
    # If-None-Match wins over If-Modified-Since, so a stale-but-matching etag would
    # 304 past a data edit: FlagshipTrend.last_modified busts on any price/model
    # write, and Date.current busts daily since the chart's right edge and year
    # ticks track today.
    return if catalog_fresh?(etag: [ :trends, Date.current, FlagshipTrend.last_modified ],
      last_modified: FlagshipTrend.last_modified)

    @trends = FlagshipTrend.all
  end
end
