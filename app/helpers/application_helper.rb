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

  # [value, label] for the tier checkboxes, sourced from TIER_LABELS so the tier
  # set and its order live in one place. No "All" entry — an empty selection
  # already means "all tiers", the same convention the provider facet uses.
  def tier_options = TIER_LABELS.map { |value, label| [ value, label ] }

  # [term, description] rows for the tier legend, off the same single source.
  def tier_legend_entries = TIER_LABELS.map { |value, label| [ label, tier_description(value) ] }

  # A multi-select filter checkbox styled as a .tp-check row — the shared shape
  # for every facet (tier / provider / modality). `leading` renders before the
  # check box (e.g. a provider's brand square); the block is the row's label.
  # Active state is CSS-driven off :checked (.tp-check:has(:checked)), so nothing
  # here needs a render-time class — the rows sit outside the Turbo frame the
  # filter form replaces and a class wouldn't refresh.
  def filter_check(name, value, checked:, leading: nil, &label)
    tag.label class: "tp-check" do
      safe_join([
        check_box_tag("#{name}[]", value, checked, id: "#{name}_#{value}",
          data: { action: "change->filters#submit" }),
        leading,
        tag.span(icon(:check, size: 12), class: "tp-check-box"),
        capture(&label)
      ].compact)
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

  # Official brand marks, drawn from each provider's own logo and rendered
  # monochrome (fill="currentColor") so they sit as a single white glyph on the
  # provider's accent square. For Alibaba we use the Qwen mark — that's the AI
  # brand (qwen.ai) these listings actually cover. Black Forest Labs is absent
  # on purpose: it publishes no clean single-path SVG mark, so it falls back to
  # its initial rather than an invented approximation.
  PROVIDER_LOGOS = {
    "anthropic" => '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M17.3041 3.541h-3.6718l6.696 16.918H24Zm-10.6082 0L0 20.459h3.7442l1.3693-3.5527h7.0052l1.3693 3.5528h3.7442L10.5363 3.5409Zm-.3712 10.2232 2.2914-5.9456 2.2914 5.9456Z"/></svg>',
    "openai" => '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M22.2819 9.8211a5.9847 5.9847 0 0 0-.5157-4.9108 6.0462 6.0462 0 0 0-6.5098-2.9A6.0651 6.0651 0 0 0 4.9807 4.1818a5.9847 5.9847 0 0 0-3.9977 2.9 6.0462 6.0462 0 0 0 .7427 7.0966 5.98 5.98 0 0 0 .511 4.9107 6.051 6.051 0 0 0 6.5146 2.9001A5.9847 5.9847 0 0 0 13.2599 24a6.0557 6.0557 0 0 0 5.7718-4.2058 5.9894 5.9894 0 0 0 3.9977-2.9001 6.0557 6.0557 0 0 0-.7475-7.0729zm-9.022 12.6081a4.4755 4.4755 0 0 1-2.8764-1.0408l.1419-.0804 4.7783-2.7582a.7948.7948 0 0 0 .3927-.6813v-6.7369l2.02 1.1686a.071.071 0 0 1 .038.052v5.5826a4.504 4.504 0 0 1-4.4945 4.4944zm-9.6607-4.1254a4.4708 4.4708 0 0 1-.5346-3.0137l.142.0852 4.783 2.7582a.7712.7712 0 0 0 .7806 0l5.8428-3.3685v2.3324a.0804.0804 0 0 1-.0332.0615L9.74 19.9502a4.4992 4.4992 0 0 1-6.1408-1.6464zM2.3408 7.8956a4.485 4.485 0 0 1 2.3655-1.9728V11.6a.7664.7664 0 0 0 .3879.6765l5.8144 3.3543-2.0201 1.1685a.0757.0757 0 0 1-.071 0l-4.8303-2.7865A4.504 4.504 0 0 1 2.3408 7.872zm16.5963 3.8558L13.1038 8.364 15.1192 7.2a.0757.0757 0 0 1 .071 0l4.8303 2.7913a4.4944 4.4944 0 0 1-.6765 8.1042v-5.6772a.79.79 0 0 0-.407-.667zm2.0107-3.0231l-.142-.0852-4.7735-2.7818a.7759.7759 0 0 0-.7854 0L9.409 9.2297V6.8974a.0662.0662 0 0 1 .0284-.0615l4.8303-2.7866a4.4992 4.4992 0 0 1 6.6802 4.66zM8.3065 12.863l-2.02-1.1638a.0804.0804 0 0 1-.038-.0567V6.0742a4.4992 4.4992 0 0 1 7.3757-3.4537l-.142.0805L8.704 5.459a.7948.7948 0 0 0-.3927.6813zm1.0976-2.3654l2.602-1.4998 2.6069 1.4998v2.9994l-2.5974 1.4997-2.6067-1.4997Z"/></svg>',
    "google" => '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12.48 10.92v3.28h7.84c-.24 1.84-.853 3.187-1.787 4.133-1.147 1.147-2.933 2.4-6.053 2.4-4.827 0-8.6-3.893-8.6-8.72s3.773-8.72 8.6-8.72c2.6 0 4.507 1.027 5.907 2.347l2.307-2.307C18.747 1.44 16.133 0 12.48 0 5.867 0 .307 5.387.307 12s5.56 12 12.173 12c3.573 0 6.267-1.173 8.373-3.36 2.16-2.16 2.84-5.213 2.84-7.667 0-.76-.053-1.467-.173-2.053H12.48z"/></svg>',
    "meta" => '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M6.915 4.03c-1.968 0-3.683 1.28-4.871 3.113C.704 9.208 0 11.883 0 14.449c0 .706.07 1.369.21 1.973a6.624 6.624 0 0 0 .265.86 5.297 5.297 0 0 0 .371.761c.696 1.159 1.818 1.927 3.593 1.927 1.497 0 2.633-.671 3.965-2.444.76-1.012 1.144-1.626 2.663-4.32l.756-1.339.186-.325c.061.1.121.196.183.3l2.152 3.595c.724 1.21 1.665 2.556 2.47 3.314 1.046.987 1.992 1.22 3.06 1.22 1.075 0 1.876-.355 2.455-.843a3.743 3.743 0 0 0 .81-.973c.542-.939.861-2.127.861-3.745 0-2.72-.681-5.357-2.084-7.45-1.282-1.912-2.957-2.93-4.716-2.93-1.047 0-2.088.467-3.053 1.308-.652.57-1.257 1.29-1.82 2.05-.69-.875-1.335-1.547-1.958-2.056-1.182-.966-2.315-1.303-3.454-1.303zm10.16 2.053c1.147 0 2.188.758 2.992 1.999 1.132 1.748 1.647 4.195 1.647 6.4 0 1.548-.368 2.9-1.839 2.9-.58 0-1.027-.23-1.664-1.004-.496-.601-1.343-1.878-2.832-4.358l-.617-1.028a44.908 44.908 0 0 0-1.255-1.98c.07-.109.141-.224.211-.327 1.12-1.667 2.118-2.602 3.358-2.602zm-10.201.553c1.265 0 2.058.791 2.675 1.446.307.327.737.871 1.234 1.579l-1.02 1.566c-.757 1.163-1.882 3.017-2.837 4.338-1.191 1.649-1.81 1.817-2.486 1.817-.524 0-1.038-.237-1.383-.794-.263-.426-.464-1.13-.464-2.046 0-2.221.63-4.535 1.66-6.088.454-.687.964-1.226 1.533-1.533a2.264 2.264 0 0 1 1.088-.285z"/></svg>',
    "mistral" => '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M17.143 3.429v3.428h-3.429v3.429h-3.428V6.857H6.857V3.43H3.43v13.714H0v3.428h10.286v-3.428H6.857v-3.429h3.429v3.429h3.429v-3.429h3.428v3.429h-3.428v3.428H24v-3.428h-3.43V3.429z"/></svg>',
    "deepseek" => '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M23.748 4.651c-.254-.124-.364.113-.512.233-.051.04-.094.09-.137.137-.372.397-.806.657-1.373.626-.829-.046-1.537.214-2.163.848-.133-.782-.575-1.248-1.247-1.548-.352-.155-.708-.311-.955-.65-.172-.24-.219-.509-.305-.774-.055-.16-.11-.323-.293-.35-.2-.031-.278.136-.356.276-.313.572-.434 1.202-.422 1.84.027 1.436.633 2.58 1.838 3.393.137.094.172.187.129.323-.082.28-.18.553-.266.833-.055.179-.137.218-.328.14a5.5 5.5 0 0 1-1.737-1.179c-.857-.828-1.631-1.743-2.597-2.46a12 12 0 0 0-.689-.47c-.985-.957.13-1.743.387-1.836.27-.098.094-.433-.778-.428-.872.003-1.67.295-2.687.685a3 3 0 0 1-.465.136 9.6 9.6 0 0 0-2.883-.101c-1.885.21-3.39 1.1-4.497 2.622C.082 8.776-.231 10.854.152 13.02c.403 2.284 1.568 4.175 3.36 5.653 1.857 1.533 3.997 2.284 6.438 2.14 1.482-.085 3.132-.284 4.994-1.86.47.234.962.328 1.78.398.629.058 1.235-.031 1.705-.129.735-.155.684-.836.418-.961-2.155-1.004-1.682-.595-2.112-.926 1.095-1.295 2.768-3.598 3.284-6.733.05-.346.115-.834.108-1.114-.004-.171.035-.238.23-.257a4.2 4.2 0 0 0 1.545-.475c1.397-.763 1.96-2.016 2.093-3.517.02-.23-.004-.467-.247-.588M11.58 18.168c-2.088-1.642-3.101-2.183-3.52-2.16-.39.024-.32.472-.234.763.09.288.207.487.371.74.114.167.192.416-.113.603-.673.416-1.842-.14-1.897-.168-1.361-.801-2.5-1.86-3.301-3.306-.775-1.393-1.225-2.888-1.299-4.482-.02-.385.094-.522.477-.592a4.7 4.7 0 0 1 1.53-.038c2.131.311 3.946 1.264 5.467 2.774.868.86 1.525 1.887 2.202 2.89.72 1.066 1.494 2.082 2.48 2.915.348.291.626.513.892.677-.802.09-2.14.109-3.055-.615zm1.001-6.44a.306.306 0 0 1 .415-.287.3.3 0 0 1 .113.074.3.3 0 0 1 .086.214c0 .17-.136.307-.308.307a.303.303 0 0 1-.306-.307m3.11 1.596c-.2.081-.4.151-.591.16a1.25 1.25 0 0 1-.798-.254c-.274-.23-.47-.358-.551-.758a1.7 1.7 0 0 1 .015-.588c.07-.327-.007-.537-.238-.727-.188-.156-.426-.199-.689-.199a.6.6 0 0 1-.254-.078.253.253 0 0 1-.114-.358 1 1 0 0 1 .192-.21c.356-.202.767-.136 1.146.016.352.144.618.408 1.001.782.392.451.462.576.685.915.176.264.336.536.446.848.066.194-.02.353-.25.45"/></svg>',
    "xai" => '<svg viewBox="0 0 841.89 595.28" fill="currentColor"><path d="m557.09 211.99 8.31 326.37h66.56l8.32-445.18zM640.28 56.91H538.72L379.35 284.53l50.78 72.52zM201.61 538.36h101.56l50.79-72.52-50.79-72.53zM201.61 211.99l228.52 326.37h101.56L303.17 211.99z"/></svg>',
    "cohere" => '<svg viewBox="0 0 75 75" fill="currentColor"><path d="M24.3 44.7c2 0 6-.1 11.6-2.4 6.5-2.7 19.3-7.5 28.6-12.5 6.5-3.5 9.3-8.1 9.3-14.3C73.8 7 66.9 0 58.3 0h-36C10 0 0 10 0 22.3s9.4 22.4 24.3 22.4z"/><path d="M30.4 60c0-6 3.6-11.5 9.2-13.8l11.3-4.7C62.4 36.8 75 45.2 75 57.6 75 67.2 67.2 75 57.6 75H45.3c-8.2 0-14.9-6.7-14.9-15z"/><path d="M12.9 47.6C5.8 47.6 0 53.4 0 60.5v1.7C0 69.2 5.8 75 12.9 75c7.1 0 12.9-5.8 12.9-12.9v-1.7c-.1-7-5.8-12.8-12.9-12.8z"/></svg>',
    "alibaba" => '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M23.919 14.545 20.817 9.17l1.47-2.544a.56.56 0 0 0 0-.566l-1.633-2.83a.57.57 0 0 0-.49-.283h-6.207L12.487.402a.57.57 0 0 0-.49-.284H8.732a.56.56 0 0 0-.49.284L5.139 5.775h-2.94a.56.56 0 0 0-.49.284L.077 8.887a.56.56 0 0 0 0 .567L3.18 14.83l-1.47 2.545a.56.56 0 0 0 0 .566l1.634 2.83a.57.57 0 0 0 .49.283h6.205l1.47 2.545a.57.57 0 0 0 .49.284h3.266a.57.57 0 0 0 .49-.284l3.104-5.375h2.94a.57.57 0 0 0 .49-.283l1.634-2.828a.55.55 0 0 0-.004-.568M8.733.686l1.634 2.828-1.634 2.828H21.8L20.164 9.17H7.425L5.63 6.06Zm1.306 19.801-6.205-.002 1.634-2.83h3.265L2.201 6.344h3.267q3.182 5.517 6.367 11.032zm10.124-5.66L18.53 12l-6.532 11.315-1.634-2.83c2.129-3.673 4.25-7.351 6.373-11.028h3.592l3.102 5.374z"/></svg>',
    "moonshot-ai" => '<svg viewBox="0 0 24 24" fill="currentColor"><path d="m1.053 16.91 9.538 2.55a21 20.981 0 0 0 .06 2.031l5.956 1.592a12 11.99 0 0 1-15.554-6.172m-1.02-5.79 11.352 3.035a21 20.981 0 0 0-.469 2.01l10.817 2.89a12 11.99 0 0 1-1.845 2.004L.658 15.918a12 11.99 0 0 1-.625-4.796m1.593-5.146L13.573 9.17a21 20.981 0 0 0-1.01 1.874l11.297 3.02a21 20.981 0 0 1-.67 2.362l-11.55-3.087L.125 10.26a12 11.99 0 0 1 1.499-4.285ZM6.067 1.58l11.285 3.016a21 20.981 0 0 0-1.688 1.719l7.824 2.091a21 20.981 0 0 1 .513 2.664L2.107 5.218a12 11.99 0 0 1 3.96-3.638M21.68 4.866 7.222 1.003A12 11.99 0 0 1 21.68 4.866"/></svg>',
    "stability-ai" => '<svg viewBox="0 0 256 213" fill="currentColor"><path d="M72.418 212.45c49.478 0 81.658-26.205 81.658-65.626 0-30.572-19.572-49.998-54.569-58.043l-22.469-6.74c-19.71-4.424-31.215-9.738-28.505-23.312 2.255-11.292 9.002-17.667 24.69-17.667 49.872 0 68.35 17.667 68.35 17.667V16.237S123.583 0 73.223 0C25.757 0 0 24.424 0 62.236c0 30.571 17.85 48.35 54.052 56.798 2.534.633 3.83.959 3.885.976 5.507 1.704 12.938 3.956 22.293 6.755 18.504 4.425 23.262 9.121 23.262 23.2 0 12.872-13.374 20.19-31.074 20.19C21.432 170.154 0 144.36 0 144.36v47.078s13.402 21.01 72.418 21.01Z"/><path d="M225.442 209.266c17.515 0 30.558-12.67 30.558-29.812 0-17.515-12.67-29.813-30.558-29.813-17.515 0-30.185 12.298-30.185 29.813s12.67 29.812 30.185 29.812Z"/></svg>'
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

  # Brand mark SVG — terminal-style $ with a cursor underscore
  def brand_mark(size = 26)
    raw <<~SVG
      <svg class="tp-brand-mark" width="#{size}" height="#{size}" viewBox="0 0 40 40" fill="none" aria-hidden="true" focusable="false">
        <defs><radialGradient id="bm-#{size}" cx="32%" cy="24%" r="82%">
          <stop offset="0" stop-color="#8b93ff"/><stop offset="55%" stop-color="#6366f1"/><stop offset="100%" stop-color="#4338ca"/>
        </radialGradient></defs>
        <rect x="2" y="2" width="36" height="36" rx="11" fill="url(#bm-#{size})"/>
        <text x="15" y="20.5" text-anchor="middle" dominant-baseline="central" fill="#fff" font-family="JetBrains Mono, monospace" font-weight="700" font-size="18">$</text>
        <rect x="23.5" y="24.5" width="9" height="3" rx="1.5" fill="rgba(255,255,255,.75)"/>
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
      [ "Models",  root_path,    -> { current_page?(root_path) } ],
      [ "Compare", compare_path, -> { current_page?(compare_path) } ],
      [ "Trends",  trends_path,  -> { current_page?(trends_path) } ],
      [ "Events",  events_path,  -> { events_active? } ]
    ]
  end

  # True when the current page is anywhere in the events section, regardless of
  # which kind filter is active. Used by the nav so the Events link stays lit on
  # all /events?kind=* views, not just the default market one.
  def events_active?
    request.path == events_path
  end

  def learn_nav_items
    [
      [ "All explainers", learn_path ],
      [ "How pricing works", how_pricing_works_path ],
      [ "What drives feature cost", learn_feature_costs_path ],
      [ "Cost-cutting strategies", learn_cost_cutting_path ],
      [ "Reasoning tokens", learn_reasoning_path ]
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

  def org_ref
    { "@type": "Organization", "@id": "#{request.base_url}/#organization" }
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
    info: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="M12 16v-4M12 8h.01"/></svg>',
    server: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="3" width="20" height="8" rx="2"/><rect x="2" y="13" width="20" height="8" rx="2"/><path d="M6 7h.01M6 17h.01"/></svg>',
    close: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>',
    columns: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2"/><path d="M12 3v18"/></svg>'
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
