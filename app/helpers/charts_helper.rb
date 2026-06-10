module ChartsHelper
  # Server-rendered SVG line chart of a model's input/output price history.
  # No JS, no external libs — renders identically for crawlers and users.
  #
  # `points` is an array of PricePoint ordered chronologically.
  def price_history_chart(points, width: 720, height: 240)
    if points.size < 2
      return content_tag(:p, "Only one price on record so far — the history chart appears once a price changes.",
                         class: "text-sm text-slate-500")
    end

    pad = { l: 14, r: 70, t: 18, b: 30 }
    plot_w = width - pad[:l] - pad[:r]
    plot_h = height - pad[:t] - pad[:b]

    xs = points.map { |p| p.effective_on.to_time.to_i }
    xmin, xmax = xs.minmax
    xspan = [ xmax - xmin, 1 ].max

    values = points.flat_map { |p| [ p.input_per_mtok.to_f, p.output_per_mtok.to_f ] }
    ymax = values.max * 1.15
    ymax = 1.0 if ymax.zero?

    sx = ->(t) { pad[:l] + ((t - xmin).to_f / xspan) * plot_w }
    sy = ->(v) { pad[:t] + (1 - (v.to_f / ymax)) * plot_h }

    series = [
      { key: :output_per_mtok, label: "Output", color: "#e11d48" },
      { key: :input_per_mtok,  label: "Input",  color: "#4f46e5" }
    ]

    svg = []
    svg << %(<svg viewBox="0 0 #{width} #{height}" class="w-full h-auto" role="img" aria-label="Price history chart">)

    # Baseline
    svg << %(<line x1="#{pad[:l]}" y1="#{sy.(0)}" x2="#{pad[:l] + plot_w}" y2="#{sy.(0)}" stroke="#e2e8f0" stroke-width="1"/>)

    series.each do |s|
      pts = points.map { |p| "#{sx.(p.effective_on.to_time.to_i).round(1)},#{sy.(p.public_send(s[:key])).round(1)}" }
      svg << %(<polyline points="#{pts.join(' ')}" fill="none" stroke="#{s[:color]}" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round"/>)

      points.each do |p|
        cx = sx.(p.effective_on.to_time.to_i).round(1)
        cy = sy.(p.public_send(s[:key])).round(1)
        svg << %(<circle cx="#{cx}" cy="#{cy}" r="3.5" fill="#fff" stroke="#{s[:color]}" stroke-width="2"><title>#{s[:label]} on #{p.effective_on.strftime('%-d %b %Y')}: #{usd(p.public_send(s[:key]))}</title></circle>)
      end

      # End-of-line value label
      last = points.last
      ly = sy.(last.public_send(s[:key])).round(1)
      svg << %(<text x="#{(pad[:l] + plot_w + 6).round(1)}" y="#{ly + 4}" font-size="12" font-weight="600" fill="#{s[:color]}">#{usd(last.public_send(s[:key]))}</text>)
    end

    # X-axis date labels (first + last)
    svg << %(<text x="#{pad[:l]}" y="#{height - 8}" font-size="11" fill="#94a3b8">#{points.first.effective_on.strftime('%b %Y')}</text>)
    svg << %(<text x="#{(pad[:l] + plot_w).round(1)}" y="#{height - 8}" font-size="11" fill="#94a3b8" text-anchor="end">#{points.last.effective_on.strftime('%b %Y')}</text>)

    svg << "</svg>"
    svg.join.html_safe
  end

  def chart_legend
    safe_join([
      content_tag(:span, "Input", class: "inline-flex items-center gap-1.5 text-xs font-medium text-slate-600 before:h-2 before:w-2 before:rounded-full before:bg-indigo-600 before:content-['']"),
      content_tag(:span, "Output", class: "inline-flex items-center gap-1.5 text-xs font-medium text-slate-600 before:h-2 before:w-2 before:rounded-full before:bg-rose-600 before:content-['']")
    ], tag.span(class: "mx-3"))
  end
end
