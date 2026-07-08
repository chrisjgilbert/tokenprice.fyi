module ModelsHelper
  # Short column labels for a PriceMove's dimensions, shown on the homepage
  # "recent price changes" strip.
  PRICE_MOVE_LABELS = { input: "in", output: "out", cached: "cached" }.freeze

  def price_move_label(dimension) = PRICE_MOVE_LABELS[dimension]
end
