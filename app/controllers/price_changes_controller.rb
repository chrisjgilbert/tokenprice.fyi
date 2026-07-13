class PriceChangesController < ApplicationController
  # The raw, automated feed of catalog price changes in the last 30 days — a
  # utility view separate from the curated /events timeline (which surfaces only
  # the significant moves, hand-written as market events). This is where the
  # Slack price-moves digest links.
  def index
    return if catalog_fresh?(etag: [ :price_changes ], last_modified: PriceCatalog.last_modified)

    @moves = PriceCatalog.recent_price_moves(limit: 40)
  end
end
