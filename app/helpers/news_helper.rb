module NewsHelper
  # The classifier's kinds that earn a badge on the feed. `other`/`nil` render no
  # badge, so an off-topic-but-relevant item stays uncluttered.
  KIND_LABELS = { "release" => "Release", "price" => "Price", "market" => "Market" }.freeze

  def news_kind_badge(kind)
    label = KIND_LABELS[kind]
    return unless label

    content_tag(:span, label, class: "tp-badge tp-kind-#{kind}")
  end
end
