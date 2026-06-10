module ApplicationHelper
  # Format a USD-per-million-tokens figure. Sub-dollar prices keep more
  # precision (DeepSeek is $0.435); dollar-plus prices show cents.
  # Returns a styled "—" span for nil (HTML — only use in HTML contexts).
  def usd(value)
    return content_tag(:span, "—", class: "text-slate-500") if value.nil?

    "$#{usd_amount(value)}"
  end

  # Plain-text money string (no HTML). Safe to interpolate into SVG/attributes.
  def usd_plain(value)
    value.nil? ? "—" : "$#{usd_amount(value)}"
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
            class: "group inline-flex items-center gap-1 #{'text-indigo-600' if active}",
            "aria-label": "Sort by #{label.downcase}, #{next_dir == 'asc' ? 'ascending' : 'descending'}" do
      safe_join([ label, content_tag(:span, arrow, "aria-hidden": "true", class: "text-[10px] #{'opacity-100' if active} #{'opacity-0 group-hover:opacity-40' unless active}") ], " ")
    end
  end

  HEX_COLOR = /\A#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})\z/

  # Only let a validated hex colour reach an inline style attribute.
  def safe_hex(value, fallback = "#6366f1")
    value.to_s.match?(HEX_COLOR) ? value : fallback
  end

  # Emit a JSON-LD <script> block. Escapes "</" so a model/provider name can
  # never break out of the script element.
  def json_ld(data)
    content_tag :script, raw(JSON.generate(data).gsub("</", '<\/')), type: "application/ld+json"
  end

  # The current sort direction for a column, as an aria-sort value.
  def aria_sort_for(key, current_sort:, current_dir:)
    return "none" unless current_sort == key

    current_dir == "asc" ? "ascending" : "descending"
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

  private

  def usd_amount(value)
    value = value.to_f
    if value.zero?
      "0"
    elsif value < 1
      format("%.4f", value).sub(/0+$/, "").sub(/\.$/, "")
    else
      format("%.2f", value)
    end
  end
end
