module ApplicationHelper
  # Format a USD-per-million-tokens figure.
  # Sub-dollar: up to 3 decimals. Dollar-plus: 2 decimals. Drop trailing zeros.
  def usd(value)
    return content_tag(:span, "—", class: "tp-muted-dash") if value.nil?

    "$#{usd_amount(value)}"
  end

  def usd_plain(value)
    value.nil? ? "—" : "$#{usd_amount(value)}"
  end

  # I/O shorthand: "$3 / $15" — the primary at-a-glance price
  def io_price(model, tag: false, big: false, light: false)
    classes = "tp-io num"
    classes += " tp-io-big" if big
    classes += " tp-io-light" if light
    sep = content_tag(:span, "/", class: "tp-io-sep")
    io_tag = tag ? content_tag(:span, "I/O", class: "tp-io-tag") : "".html_safe
    content_tag(:span, class: classes) do
      content_tag(:span, usd(model.current_input), class: "tp-io-v") +
        sep +
        content_tag(:span, usd(model.current_output), class: "tp-io-v") +
        io_tag
    end
  end

  # Price change badge (delta pill)
  def price_change_badge(percent)
    return if percent.nil?

    up = percent.positive?
    css = up ? "tp-delta tp-delta-up" : "tp-delta tp-delta-down"
    arrow_svg = if up
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 7h6v6"/><path d="m22 7-8.5 8.5-5-5L2 17"/></svg>'
    else
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 17h6v-6"/><path d="m22 17-8.5-8.5-5 5L2 7"/></svg>'
    end
    content_tag(:span, class: css) do
      raw(arrow_svg) + " #{number_to_percentage(percent.abs, precision: 1)}"
    end
  end

  TIER_CLASSES = {
    "frontier" => "tp-tier-frontier",
    "mid"      => "tp-tier-mid",
    "small"    => "tp-tier-small"
  }.freeze

  TIER_LABELS = { "frontier" => "Frontier", "mid" => "Mid", "small" => "Small" }.freeze

  def tier_badge(tier)
    content_tag(:span, class: "tp-badge #{TIER_CLASSES.fetch(tier, '')}") do
      content_tag(:span, "", class: "tp-badge-dot") + TIER_LABELS.fetch(tier, tier.to_s.titleize)
    end
  end

  def status_badge(status)
    return if status == "active"

    css = "tp-status tp-status-#{status}"
    content_tag(:span, status, class: css)
  end

  # Provider square — colored icon with initial
  def provider_square(provider, size: :md)
    css = "tp-prov-sq tp-prov-sq-#{size}"
    initial = provider.name.to_s[0]&.upcase || "?"
    content_tag(:span, initial, class: css, style: "background:#{safe_hex(provider.accent)}")
  end

  # Brand mark SVG — token-coin with $
  def brand_mark(size = 26)
    raw <<~SVG
      <svg class="tp-brand-mark" width="#{size}" height="#{size}" viewBox="0 0 40 40" fill="none" aria-hidden="true" focusable="false">
        <defs><radialGradient id="bm-#{size}" cx="32%" cy="24%" r="82%">
          <stop offset="0" stop-color="#8b93ff"/><stop offset="55%" stop-color="#6366f1"/><stop offset="100%" stop-color="#4338ca"/>
        </radialGradient></defs>
        <circle cx="20" cy="20" r="19" fill="url(#bm-#{size})"/>
        <circle cx="20" cy="20" r="17.4" fill="none" stroke="rgba(255,255,255,.55)" stroke-width="2.6" stroke-dasharray="0.5 3.1" stroke-linecap="round"/>
        <circle cx="20" cy="20" r="14" fill="none" stroke="rgba(255,255,255,.92)" stroke-width="1.4"/>
        <text x="20" y="20.5" text-anchor="middle" dominant-baseline="central" fill="#fff" font-family="JetBrains Mono, monospace" font-weight="700" font-size="18.5">$</text>
      </svg>
    SVG
  end

  # Nav link helper
  def nav_link(label, path, active: false)
    css = "tp-nav-link"
    css += " active" if active
    link_to label, path, class: css
  end

  # Sort link for table headers
  def sort_link(label, key, current_sort:, current_dir:, filters: {}, &url_builder)
    active = current_sort == key
    next_dir = active && current_dir == "asc" ? "desc" : "asc"
    sort_params = filters.merge(sort: key, dir: next_dir)
    target_url = block_given? ? yield(sort_params) : root_path(sort_params)

    arrow_svg = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="m6 15 6-6 6 6"/></svg>'

    link_to target_url,
            class: "tp-th-inner",
            data: { turbo_frame: "models", turbo_action: "advance" },
            "aria-label": "Sort by #{label.downcase}, #{next_dir == 'asc' ? 'ascending' : 'descending'}" do
      safe_join([
        label,
        content_tag(:span, raw(arrow_svg), class: "tp-sort-arrow")
      ])
    end
  end

  HEX_COLOR = /\A#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})\z/

  def safe_hex(value, fallback = "#6366f1")
    value.to_s.match?(HEX_COLOR) ? value : fallback
  end

  def json_ld(data)
    content_tag :script, raw(JSON.generate(data).gsub("</", '<\/')), type: "application/ld+json"
  end

  def aria_sort_for(key, current_sort:, current_dir:)
    return "none" unless current_sort == key

    current_dir == "asc" ? "ascending" : "descending"
  end

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

  # Common SVG icons (Lucide-style)
  ICONS = {
    search: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/></svg>',
    chevron_right: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m9 18 6-6-6-6"/></svg>',
    arrow_up: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="m6 15 6-6 6 6"/></svg>',
    chevron_down: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="m18 9-6 6-6-6"/></svg>',
    check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>',
    swap: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m17 2 4 4-4 4"/><path d="M3 6h18"/><path d="m7 22-4-4 4-4"/><path d="M21 18H3"/></svg>',
    external: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 3h6v6"/><path d="M10 14 21 3"/><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/></svg>',
    spark: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v3m0 12v3M3 12h3m12 0h3M5.6 5.6l2.1 2.1m8.6 8.6 2.1 2.1m0-12.8-2.1 2.1m-8.6 8.6-2.1 2.1"/></svg>',
    trend_down: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 17h6v-6"/><path d="m22 17-8.5-8.5-5 5L2 7"/></svg>',
    empty: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M3 7v10a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V7"/><path d="M3 7l9 6 9-6"/><path d="M3 7l9-4 9 4"/></svg>',
    calendar: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/></svg>'
  }.freeze

  def icon(name, size: 17)
    raw "<span style=\"display:inline-flex;width:#{size}px;height:#{size}px\">#{ICONS[name]}</span>"
  end

  # Format date as "Mon YYYY"
  def fmt_date(date)
    return "—" if date.nil?
    date.strftime("%b %Y")
  end

  # Format date as "Mon D, YYYY"
  def fmt_date_full(date)
    return "—" if date.nil?
    date.strftime("%b %-d, %Y")
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
