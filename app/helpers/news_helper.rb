module NewsHelper
  # The classifier's kinds that earn a badge on the feed. `other`/`nil` render no
  # badge, so an off-topic-but-relevant item stays uncluttered.
  KIND_LABELS = { "release" => "Release", "price" => "Price", "market" => "Market" }.freeze

  def news_kind_badge(kind)
    label = KIND_LABELS[kind]
    return unless label

    content_tag(:span, label, class: "tp-badge tp-kind-#{kind}")
  end

  # Short column labels for a PriceMove's dimensions on the recent-changes strip.
  PRICE_MOVE_LABELS = { input: "in", output: "out", cached: "cached" }.freeze

  def price_move_label(dimension) = PRICE_MOVE_LABELS[dimension]
end
