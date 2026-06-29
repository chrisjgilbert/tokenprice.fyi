module ApplicationHelper
  # An external URL safe to drop into an href: returned only when it's a plain
  # http(s) link, so a stored value can't smuggle a `javascript:`/`data:` scheme
  # into a link target. Returns nil (render no link) for anything else.
  def external_href(url)
    url if url.to_s.match?(%r{\Ahttps?://\S+\z}i)
  end

  # Format a USD-per-million-tokens figure. The numeric rule lives in PriceFormat
  # so the insight services format identically; this layer adds HTML/em-dash.
  def usd(value, decimals: 4)
    return content_tag(:span, "—", class: "tp-muted-dash") if value.nil?

    "$#{PriceFormat.usd_amount(value, decimals: decimals)}"
  end

  def usd_plain(value, decimals: 4)
    value.nil? ? "—" : "$#{PriceFormat.usd_amount(value, decimals: decimals)}"
  end

  # The compact price subtitle in the compare model-picker dropdown: the input rate.
  def picker_price(model)
    "#{usd(model.current_input)} in"
  end

  # I/O shorthand: "$3 / $15" — the primary at-a-glance price (the chip on the hero
  # card and the launch timeline).
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

  # Price change badge (delta pill). Direction is shown visually by the arrow
  # and colour; an sr-only word carries the same meaning to screen readers, and
  # the arrow SVG is marked decorative.
  def price_change_badge(percent)
    return if percent.nil?

    up = percent.positive?
    css = up ? "tp-delta tp-delta-up" : "tp-delta tp-delta-down"
    arrow_svg = if up
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false"><path d="M16 7h6v6"/><path d="m22 7-8.5 8.5-5-5L2 17"/></svg>'
    else
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false"><path d="M16 17h6v-6"/><path d="m22 17-8.5-8.5-5 5L2 7"/></svg>'
    end
    content_tag(:span, class: css) do
      content_tag(:span, (up ? "increased " : "decreased "), class: "sr-only") +
        raw(arrow_svg) + " #{number_to_percentage(percent.abs, precision: 1)}"
    end
  end

  TIER_CLASSES = {
    "frontier" => "tp-tier-frontier",
    "mid"      => "tp-tier-mid",
    "small"    => "tp-tier-small"
  }.freeze

  TIER_LABELS = { "frontier" => "Frontier", "mid" => "Mid", "small" => "Small" }.freeze

  TIER_DESCRIPTIONS = {
    "frontier" => "A provider's most capable, highest-priced models.",
    "mid"      => "Mid-range models — cheaper than frontier, capable for most work.",
    "small"    => "The smallest, cheapest models — for high-volume, well-defined tasks."
  }.freeze

  def tier_description(tier) = TIER_DESCRIPTIONS[tier.to_s]

  # [label, value] for the tier pills, sourced from TIER_LABELS so the tier set
  # and its order live in one place. The leading "All" pill clears the filter.
  def tier_pill_options = [ [ "All", "" ] ] + TIER_LABELS.map { |value, label| [ label, value ] }

  # [term, description] rows for the tier legend, off the same single source.
  def tier_legend_entries = TIER_LABELS.map { |value, label| [ label, tier_description(value) ] }

  # The active state is CSS-driven off the checked radio (.tp-pill:has(input:checked)),
  # so the label just wraps the visually hidden input.
  def filter_pill(name, value, label, checked:)
    tag.label class: "tp-pill" do
      radio_button_tag(name, value, checked, class: "sr-only",
        data: { action: "change->filters#submit" }) + label
    end
  end

  def tier_badge(tier)
    content_tag(:span, class: "tp-badge #{TIER_CLASSES.fetch(tier, '')}") do
      content_tag(:span, "", class: "tp-badge-dot") + TIER_LABELS.fetch(tier, tier.to_s.titleize)
    end
  end

  # A small pill naming a model's modality class — shown only for non-text
  # models, so a plain text row stays uncluttered. Returns nil for :text.
  def modality_badge(model)
    return if model.modality_class == :text

    content_tag(:span, ModalityClass.label(model.modality_class), class: "tp-modality-badge")
  end

  def status_badge(status)
    return if status == "active"

    css = "tp-status tp-status-#{status}"
    content_tag(:span, status, class: css)
  end

  PROVIDER_LOGOS = {
    "anthropic" => '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M13.827 3.52l5.51 16.96H16.1L10.59 3.52h3.238zM4.663 20.48L7.9 11.14l1.62 4.99L7.9 20.48H4.663z"/></svg>',
    "openai" => '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M22.282 9.821a5.985 5.985 0 0 0-.516-4.91 6.046 6.046 0 0 0-6.51-2.9A6.065 6.065 0 0 0 4.981 4.18a5.998 5.998 0 0 0-3.998 2.9 6.049 6.049 0 0 0 .743 7.097 5.98 5.98 0 0 0 .51 4.911 6.051 6.051 0 0 0 6.515 2.9A5.985 5.985 0 0 0 13.26 24a6.056 6.056 0 0 0 5.772-4.206 5.99 5.99 0 0 0 3.997-2.9 6.056 6.056 0 0 0-.747-7.073zM13.26 22.43a4.476 4.476 0 0 1-2.876-1.04l.141-.081 4.779-2.758a.795.795 0 0 0 .392-.681v-6.737l2.02 1.168a.071.071 0 0 1 .038.052v5.583a4.504 4.504 0 0 1-4.494 4.494zM3.6 18.304a4.47 4.47 0 0 1-.535-3.014l.142.085 4.783 2.759a.771.771 0 0 0 .78 0l5.843-3.369v2.332a.08.08 0 0 1-.033.062L9.74 19.95a4.5 4.5 0 0 1-6.14-1.646zM2.34 7.896a4.485 4.485 0 0 1 2.366-1.973V11.6a.766.766 0 0 0 .388.676l5.815 3.355-2.02 1.168a.076.076 0 0 1-.071 0l-4.83-2.786A4.504 4.504 0 0 1 2.34 7.872zm16.597 3.855l-5.833-3.387L15.119 7.2a.076.076 0 0 1 .071 0l4.83 2.791a4.494 4.494 0 0 1-.676 8.105v-5.678a.79.79 0 0 0-.407-.667zm2.01-3.023l-.141-.085-4.774-2.782a.776.776 0 0 0-.785 0L9.409 9.23V6.897a.066.066 0 0 1 .028-.061l4.83-2.787a4.5 4.5 0 0 1 6.68 4.66zm-12.64 4.135l-2.02-1.164a.08.08 0 0 1-.038-.057V6.075a4.5 4.5 0 0 1 7.375-3.453l-.142.08L8.704 5.46a.795.795 0 0 0-.393.681zm1.097-2.365l2.602-1.5 2.607 1.5v2.999l-2.597 1.5-2.607-1.5z"/></svg>',
    "google" => '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z" fill="#4285F4"/><path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/><path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/><path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/></svg>',
    "meta" => '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M6.915 4.03c-1.968 0-3.49 1.06-4.537 2.93C1.306 8.793.684 11.2.684 13.81c0 1.837.384 3.308 1.088 4.14.608.716 1.42 1.065 2.376 1.065 1.301 0 2.408-.81 3.69-2.757.917-1.393 1.793-3.108 2.622-4.878l.043-.094c.63-1.343 1.3-2.766 2.071-3.996.992-1.582 2.172-2.804 3.627-3.195a5.453 5.453 0 0 1 1.107-.125c2.268 0 3.98 1.063 5.036 2.93 1.072 1.894 1.656 4.55 1.656 7.47 0 1.837-.384 3.308-1.088 4.14-.608.717-1.42 1.065-2.376 1.065-1.398 0-2.553-.903-3.87-2.94-.89-1.378-1.741-3.06-2.558-4.812l-.104-.227c-.618-1.314-1.273-2.697-2.024-3.89-.992-1.582-2.172-2.804-3.627-3.195A5.49 5.49 0 0 0 6.915 4.03zM4.148 5.88c.756-1.202 1.63-1.85 2.767-1.85.452 0 .875.07 1.257.222 1.108.47 2.025 1.498 2.893 2.883.694 1.108 1.326 2.425 1.936 3.713l.103.225c.85 1.822 1.733 3.572 2.682 5.04 1.156 1.789 2.026 2.381 2.98 2.381.635 0 1.108-.24 1.478-.689.453-.55.712-1.478.712-2.994 0-2.694-.534-5.087-1.42-6.65-.817-1.44-1.884-2.28-3.273-2.28-.452 0-.875.07-1.257.222-1.107.47-2.025 1.498-2.893 2.883-.694 1.108-1.326 2.425-1.936 3.713l-.103.225c-.85 1.822-1.733 3.572-2.682 5.04-1.156 1.789-2.026 2.381-2.98 2.381-.635 0-1.108-.24-1.478-.689-.453-.55-.712-1.478-.712-2.994 0-2.694.534-5.087 1.42-6.65z"/></svg>',
    "mistral" => '<svg viewBox="0 0 24 24" fill="currentColor"><rect x="1" y="3" width="4" height="4" fill="#F7D046"/><rect x="19" y="3" width="4" height="4"/><rect x="1" y="9" width="4" height="4"/><rect x="7" y="9" width="4" height="4"/><rect x="13" y="9" width="4" height="4" fill="#F7D046"/><rect x="19" y="9" width="4" height="4"/><rect x="1" y="15" width="4" height="4"/><rect x="7" y="15" width="4" height="4" fill="#F2A73B"/><rect x="13" y="15" width="4" height="4"/><rect x="19" y="15" width="4" height="4"/></svg>',
    "deepseek" => '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm4.64 14.19c-.73.56-1.65.81-2.7.81-1.23 0-2.28-.39-3.12-1.1-.33-.28-.62-.6-.87-.96l-.02.02c-.19.23-.4.44-.65.62-.68.5-1.48.7-2.33.52-.82-.18-1.42-.68-1.74-1.46-.53-1.28-.06-2.88 1.06-3.68.42-.3.9-.47 1.42-.5.09 0 .18-.01.27 0 .06 0 .12.01.18.02-.05-.33-.07-.67-.04-1.01.07-.96.44-1.8 1.1-2.49.77-.8 1.72-1.23 2.83-1.29.1-.01.2-.01.3 0 1.36.05 2.47.6 3.32 1.61.74.88 1.13 1.9 1.16 3.04.02.72-.12 1.41-.42 2.06.39.15.74.37 1.04.65.86.81 1.08 1.87.21 3.14z"/></svg>',
    "xai" => '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M3.005 6.89l7.37 10.71-7.463 5.4h1.14l6.545-4.736 5.273 4.736H21L13.283 15.4l.008.012 6.96-9.522H19.15l-5.993 8.198L8.23 6.89zm1.712 1.073h2.47l11.113 15.074h-2.47z"/></svg>',
    "alibaba" => '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M6.2 12c0-1.1.3-2.1.8-3 .5-.9 1.3-1.7 2.2-2.2.9-.5 1.9-.8 3-.8s2.1.3 3 .8c.9.5 1.7 1.3 2.2 2.2.5.9.8 1.9.8 3s-.3 2.1-.8 3c-.5.9-1.3 1.7-2.2 2.2-.9.5-1.9.8-3 .8s-2.1-.3-3-.8c-.9-.5-1.7-1.3-2.2-2.2-.5-.9-.8-1.9-.8-3zm1.4 0c0 1.4.5 2.6 1.5 3.6s2.2 1.5 3.6 1.5c.9 0 1.8-.2 2.5-.7.8-.5 1.4-1.1 1.8-1.9.4-.8.7-1.6.7-2.5 0-1.4-.5-2.6-1.5-3.6S14.1 6.9 12.7 6.9c-1.4 0-2.6.5-3.6 1.5S7.6 10.6 7.6 12z"/></svg>',
    "moonshot-ai" => '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10c1.73 0 3.36-.44 4.78-1.22C13.39 19.12 10.8 16 10.8 12.3c0-3.48 2.35-6.42 5.55-7.3A9.96 9.96 0 0 0 12 2z"/></svg>'
  }.freeze

  def provider_square(provider, size: :md)
    css = "tp-prov-sq tp-prov-sq-#{size}"
    bg = "background:#{safe_hex(provider.accent)}"
    logo = PROVIDER_LOGOS[provider.slug]

    if logo
      content_tag(:span, raw(logo), class: "#{css} tp-prov-logo", style: bg)
    else
      initial = provider.name.to_s[0]&.upcase || "?"
      content_tag(:span, initial, class: css, style: bg)
    end
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

  # The single source of truth for the nav, shared by the desktop bar and the
  # mobile drawer so the two can't drift. Each item is [label, path].
  def primary_nav_items
    [
      [ "Models", root_path ],
      [ "Compare", compare_path ],
      [ "Guide", guide_path ],
      [ "Events", events_path ]
    ]
  end

  def learn_nav_items
    [
      [ "All explainers", learn_path ],
      [ "What a feature is made of", learn_anatomy_path ],
      [ "How pricing works", how_pricing_works_path ],
      [ "Reasoning tokens", learn_reasoning_path ],
      [ "What drives feature cost", learn_feature_costs_path ],
      [ "Cost-cutting strategies", learn_cost_cutting_path ]
    ]
  end

  # True when the current page is any of the Learn explainers.
  def learn_active?
    learn_nav_items.any? { |_, path| current_page?(path) }
  end

  # Mobile drawer link. `sub: true` renders the indented Learn variant.
  def mobile_nav_link(label, path, active: false, sub: false)
    css = sub ? "tp-m-sublink" : "tp-m-link"
    css += " active" if active
    link_to label, path, class: css, data: { action: "mobile-nav#close" },
                         aria: { current: ("page" if active) }
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
    calendar: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/></svg>',
    # Token-flow + capability marks for the model metric cards and editorial blocks.
    arrow_in: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v12"/><path d="m7 10 5 5 5-5"/><path d="M5 21h14"/></svg>',
    arrow_out: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 21V9"/><path d="m7 14 5-5 5 5"/><path d="M5 3h14"/></svg>',
    cache: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12a9 9 0 1 1-9-9c2.5 0 4.7 1 6.3 2.7L21 8"/><path d="M21 3v5h-5"/></svg>',
    brackets: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M8 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h3"/><path d="M16 3h3a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-3"/></svg>',
    bolt: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M13 2 3 14h9l-1 8 10-12h-9l1-8Z"/></svg>',
    target: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1"/></svg>',
    warn: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z"/><path d="M12 9v4M12 17h.01"/></svg>',
    info: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="M12 16v-4M12 8h.01"/></svg>'
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

  # The "data updated <date>" stamp shown on the model and provider pages. A
  # <time> carries the precise instant (datetime attribute, relative hint in the
  # title) while the visible text stays a specific date, per the copy style —
  # "write the number", not "up to date". Returns nil when there's no timestamp.
  def data_updated_tag(timestamp, label: "Data updated", css: nil)
    return if timestamp.nil?

    tag.time "#{label} #{fmt_date_full(timestamp)}",
      datetime: timestamp.iso8601,
      title: "#{time_ago_in_words(timestamp)} ago",
      class: css
  end

  # Where "Report a problem" links resolve. Same inbox as the footer Contact
  # link; named here so the report links and that link can't drift apart.
  REPORT_EMAIL = "chris@chrisgilbert.dev"

  # A prefilled "Report a problem" mailto link. Scoping the subject and body to
  # the page means a reply lands already in context, and a mailto (rather than a
  # form posting to a new endpoint) keeps the app backend-free and with no
  # spam-able write surface — in keeping with the existing Contact link.
  def report_problem_link(subject:, body:, css: nil)
    mail_to REPORT_EMAIL, "Report a problem", subject: subject, body: body, class: css
  end

  def model_report_link(model, css: nil)
    report_problem_link(
      subject: "tokenprice.fyi data issue: #{model.name}",
      body: "Model: #{model.name} (#{model.provider.name})\nPage: #{model_url(model)}\n\nWhat looks wrong?\n",
      css: css
    )
  end

  def provider_report_link(provider, css: nil)
    report_problem_link(
      subject: "tokenprice.fyi data issue: #{provider.name}",
      body: "Provider: #{provider.name}\nPage: #{provider_url(provider)}\n\nWhat looks wrong?\n",
      css: css
    )
  end
end
