module ChartsHelper
  # Server-rendered SVG line chart of a model's input/output price history.
  # No JS, no external libs — renders identically for crawlers and users.
  #
  # Accessibility: the SVG carries a <title>/<desc> summary (via aria-labelledby
  # / aria-describedby) and the two series are distinguished by line style
  # (output is dashed) and text labels, not colour alone. The page also renders
  # the underlying numbers in the "Snapshots" table beneath the chart.
  #
  # `points` is an array of PricePoint ordered chronologically.
  def price_history_chart(points, width: 720, height: 240)
    if points.size < 2
      return content_tag(:p, "Only one price on record so far — the history chart appears once a price changes.",
                         class: "text-sm text-slate-500")
    end

    pad = { l: 14, r: 96, t: 18, b: 30 }
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
      { key: :output_per_mtok, short: "Out", label: "Output", color: "#e11d48", dash: "6 4" },
      { key: :input_per_mtok,  short: "In",  label: "Input",  color: "#4f46e5", dash: nil }
    ]

    uid     = "chart-#{points.first.ai_model_id}"
    first_p = points.first
    last_p  = points.last
    desc = series.map do |s|
      "#{s[:label]} went from #{usd_plain(first_p.public_send(s[:key]))} to #{usd_plain(last_p.public_send(s[:key]))}"
    end.join("; ") + " between #{first_p.effective_on.strftime('%b %Y')} and #{last_p.effective_on.strftime('%b %Y')}."

    svg = []
    svg << %(<svg viewBox="0 0 #{width} #{height}" class="w-full h-auto" role="img" aria-labelledby="#{uid}-title #{uid}-desc">)
    svg << %(<title id="#{uid}-title">Price per 1M tokens over time</title>)
    svg << %(<desc id="#{uid}-desc">#{ERB::Util.html_escape(desc)}</desc>)

    # Baseline
    svg << %(<line x1="#{pad[:l]}" y1="#{sy.(0)}" x2="#{pad[:l] + plot_w}" y2="#{sy.(0)}" stroke="#e2e8f0" stroke-width="1"/>)

    series.each do |s|
      dash = s[:dash] ? %( stroke-dasharray="#{s[:dash]}") : ""
      pts = points.map { |p| "#{sx.(p.effective_on.to_time.to_i).round(1)},#{sy.(p.public_send(s[:key])).round(1)}" }
      svg << %(<polyline points="#{pts.join(' ')}" fill="none" stroke="#{s[:color]}" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round"#{dash}/>)

      points.each do |p|
        cx = sx.(p.effective_on.to_time.to_i).round(1)
        cy = sy.(p.public_send(s[:key])).round(1)
        svg << %(<circle cx="#{cx}" cy="#{cy}" r="3.5" fill="#fff" stroke="#{s[:color]}" stroke-width="2"><title>#{s[:label]} on #{p.effective_on.strftime('%-d %b %Y')}: #{usd_plain(p.public_send(s[:key]))}</title></circle>)
      end

      # End-of-line label, prefixed with the series name so the lines are
      # identifiable without relying on colour.
      ly = sy.(last_p.public_send(s[:key])).round(1)
      svg << %(<text x="#{(pad[:l] + plot_w + 6).round(1)}" y="#{ly + 4}" font-size="12" font-weight="600" fill="#{s[:color]}">#{s[:short]} #{usd_plain(last_p.public_send(s[:key]))}</text>)
    end

    # X-axis date labels (first + last)
    svg << %(<text x="#{pad[:l]}" y="#{height - 8}" font-size="11" fill="#475569">#{first_p.effective_on.strftime('%b %Y')}</text>)
    svg << %(<text x="#{(pad[:l] + plot_w).round(1)}" y="#{height - 8}" font-size="11" fill="#475569" text-anchor="end">#{last_p.effective_on.strftime('%b %Y')}</text>)

    svg << "</svg>"
    svg.join.html_safe
  end

  # Area sparkline of a workload's monthly cost across historical price-change
  # dates — the estimator's "priced through history" retrospective. Ported from
  # the design's co-retro SVG (sqrt-scaled so big drops stay legible).
  # `series` is an array of { date:, monthly: } ascending.
  def cost_retro_sparkline(series, width: 360, height: 70, pad: 5)
    return "".html_safe if series.size < 2

    xs = ->(i) { pad + (i.to_f / (series.size - 1)) * (width - 2 * pad) }
    vals = series.map { |s| Math.sqrt(s[:monthly]) }
    mn, mx = vals.minmax
    ys = ->(v) { height - pad - (mx == mn ? 0.5 : (v - mn) / (mx - mn)) * (height - 2 * pad) }

    line = series.each_index.map { |i| "#{i.zero? ? 'M' : 'L'}#{xs.(i).round(1)} #{ys.(vals[i]).round(1)}" }.join(" ")
    area = "M#{pad} #{height - pad} " +
           series.each_index.map { |i| "L#{xs.(i).round(1)} #{ys.(vals[i]).round(1)}" }.join(" ") +
           " L#{width - pad} #{height - pad} Z"

    raw <<~SVG
      <svg class="co-retro-svg" viewBox="0 0 #{width} #{height}" preserveAspectRatio="none" role="img" aria-label="This workload's monthly cost on the cheapest fitting model, over time">
        <defs><linearGradient id="co-retro-grad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stop-color="var(--color-indigo-400)" stop-opacity=".5"/>
          <stop offset="1" stop-color="var(--color-indigo-50)" stop-opacity="0"/>
        </linearGradient></defs>
        <path d="#{area}" fill="url(#co-retro-grad)"/>
        <path d="#{line}" fill="none" stroke="var(--color-indigo-500)" stroke-width="2" stroke-linejoin="round"/>
      </svg>
    SVG
  end

  def chart_legend
    safe_join([
      content_tag(:span, "Input (solid)", class: "inline-flex items-center gap-1.5 text-xs font-medium text-slate-600 before:h-2 before:w-2 before:rounded-full before:bg-indigo-600 before:content-['']"),
      content_tag(:span, "Output (dashed)", class: "inline-flex items-center gap-1.5 text-xs font-medium text-slate-600 before:h-2 before:w-2 before:rounded-full before:bg-rose-600 before:content-['']")
    ], tag.span(class: "mx-3"))
  end
end
