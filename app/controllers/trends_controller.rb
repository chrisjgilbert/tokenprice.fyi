class TrendsController < ApplicationController
  def show
    return if catalog_fresh?(etag: [ :trends ])

    @trends = FlagshipTrend.all
  end
end
