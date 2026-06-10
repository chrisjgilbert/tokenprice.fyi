module ApplicationHelper
  # Format a USD-per-million-tokens figure. Sub-dollar prices keep more
  # precision (DeepSeek is $0.435); dollar-plus prices show cents.
  def usd(value)
    return content_tag(:span, "—", class: "text-slate-400") if value.nil?

    value = value.to_f
    formatted =
      if value.zero?
        "0"
      elsif value < 1
        format("%.4f", value).sub(/0+$/, "").sub(/\.$/, "")
      else
        format("%.2f", value)
      end
    "$#{formatted}"
  end

  # Render a signed percentage. Cheaper (negative) is good → green; pricier → rose.
  def price_change_badge(percent)
    return if percent.nil?

    up = percent.positive?
    classes = up ? "bg-rose-50 text-rose-700 ring-rose-600/20" : "bg-emerald-50 text-emerald-700 ring-emerald-600/20"
    arrow = up ? "↑" : "↓"
    content_tag :span, "#{arrow} #{number_to_percentage(percent.abs, precision: 1)}",
                class: "inline-flex items-center gap-0.5 rounded-full px-2 py-0.5 text-xs font-medium ring-1 ring-inset #{classes}"
  end

  TIER_STYLES = {
    "frontier" => "bg-indigo-50 text-indigo-700 ring-indigo-600/20",
    "mid"      => "bg-sky-50 text-sky-700 ring-sky-600/20",
    "small"    => "bg-amber-50 text-amber-700 ring-amber-600/20"
  }.freeze

  TIER_LABELS = { "frontier" => "Frontier", "mid" => "Mid", "small" => "Small / fast" }.freeze

  def tier_badge(tier)
    content_tag :span, TIER_LABELS.fetch(tier, tier.to_s.titleize),
                class: "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ring-1 ring-inset #{TIER_STYLES.fetch(tier, 'bg-slate-50 text-slate-600 ring-slate-500/20')}"
  end

  def status_badge(status)
    return if status == "active"

    content_tag :span, status.titleize,
                class: "inline-flex items-center rounded-full bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-500"
  end

  # Clickable column header that toggles sort direction, preserving the tier filter.
  def sort_link(label, key, current_sort:, current_dir:, tier: nil)
    active = current_sort == key
    next_dir = active && current_dir == "asc" ? "desc" : "asc"
    arrow = active ? (current_dir == "asc" ? "▲" : "▼") : ""
    link_to root_path(sort: key, dir: next_dir, tier: tier),
            class: "group inline-flex items-center gap-1 #{'text-indigo-600' if active}" do
      safe_join([ label, content_tag(:span, arrow, class: "text-[10px] #{'opacity-100' if active} #{'opacity-0 group-hover:opacity-40' unless active}") ], " ")
    end
  end

  # Compact token count: 1_000_000 -> "1M", 200_000 -> "200K".
  def tokens_short(count)
    return "—" if count.nil?

    if count >= 1_000_000
      "#{(count / 1_000_000.0).round(2).to_s.sub(/\.0+$/, '')}M"
    elsif count >= 1_000
      "#{count / 1_000}K"
    else
      count.to_s
    end
  end
end
