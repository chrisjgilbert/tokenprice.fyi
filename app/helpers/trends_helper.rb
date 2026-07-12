module TrendsHelper
  # Short column labels for a PriceMove's dimensions on the recent-changes strip.
  PRICE_MOVE_LABELS = { input: "in", output: "out", cached: "cached" }.freeze

  def price_move_label(dimension) = PRICE_MOVE_LABELS[dimension]
end
