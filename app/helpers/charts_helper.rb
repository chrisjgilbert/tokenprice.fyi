module ChartsHelper
  # Line chart of a model's input/output price history, rendered as SVG on the
  # server so it's identical for crawlers, no-JS clients, and screen readers.
  # A Stimulus controller (price_chart) progressively enhances it with a
  # cursor-tracking crosshair and a floating tooltip — the static chart stands
  # on its own if that JS never runs.
  #
  # Accessibility: the SVG carries a <title>/<desc> summary (via aria-labelledby
  # / aria-describedby) and the two series are distinguished by line style
  # (output is dashed) and text labels, not colour alone. The page also renders
  # the underlying numbers in the "Snapshots" table beneath the chart.
  #
  # `points` is an array of PricePoint ordered chronologically. The chart always
  # renders given at least one point (a lone point shows as a centred marker).
  def price_history_chart(points, width: 720, height: 240)
    if points.empty?
      return content_tag(:p, "No price on record yet.", class: "text-sm text-slate-500")
    end

    # Left gutter leaves room for the dollar axis labels.
    pad = { l: 44, r: 96, t: 18, b: 30 }
    plot_w = width - pad[:l] - pad[:r]
    plot_h = height - pad[:t] - pad[:b]

    single = points.size == 1
    xs = points.map { |p| p.effective_on.to_time.to_i }
    xmin, xmax = xs.minmax
    xspan = [ xmax - xmin, 1 ].max

    values = points.flat_map { |p| [ p.input_per_mtok.to_f, p.output_per_mtok.to_f ] }
    ymax = values.max * 1.15
    ymax = 1.0 if ymax.zero?

    # A single point has no time span to spread across, so centre it.
    sx = ->(t) { single ? (pad[:l] + plot_w / 2.0) : (pad[:l] + ((t - xmin).to_f / xspan) * plot_w) }
    sy = ->(v) { pad[:t] + (1 - (v.to_f / ymax)) * plot_h }

    series = [
      { key: :output_per_mtok, short: "Out", label: "Output", color: "#e11d48", dash: "6 4", target: "outputDot" },
      { key: :input_per_mtok,  short: "In",  label: "Input",  color: "#4f46e5", dash: nil, target: "inputDot" }
    ]

    # Each point's screen position and formatted price, computed once. The
    # gridlines aside, every drawn element — polylines, markers, end labels, the
    # <desc>, and the JS hover data — reads its coordinates and labels from here.
    coords = points.each_with_index.map do |p, i|
      row = { x: sx.(xs[i]).round(1), date: p.effective_on.strftime("%-d %b %Y") }
      series.each do |s|
        v = p.public_send(s[:key])
        row[s[:key]] = { y: sy.(v).round(1), label: usd_plain(v) }
      end
      row
    end

    uid     = "chart-#{points.first.ai_model_id}"
    first_p = points.first
    last_p  = points.last
    desc =
      if single
        series.map { |s| "#{s[:label]} #{coords.first[s[:key]][:label]}" }.join("; ") +
          " as of #{first_p.effective_on.strftime('%b %Y')}."
      else
        series.map do |s|
          "#{s[:label]} went from #{coords.first[s[:key]][:label]} to #{coords.last[s[:key]][:label]}"
        end.join("; ") + " between #{first_p.effective_on.strftime('%b %Y')} and #{last_p.effective_on.strftime('%b %Y')}."
      end

    svg = []
    svg << %(<svg viewBox="0 0 #{width} #{height}" class="w-full h-auto" role="img" aria-labelledby="#{uid}-title #{uid}-desc" data-price-chart-target="svg">)
    svg << %(<title id="#{uid}-title">Price per 1M tokens over time</title>)
    svg << %(<desc id="#{uid}-desc">#{ERB::Util.html_escape(desc)}</desc>)

    # Horizontal gridlines at round dollar values, each with a mono $ label in
    # the left gutter (the design's "$/1M" axis). The step is chosen so ~4–6
    # lines land on clean numbers across every price scale (cents to tens).
    chart_gridlines(ymax).each do |v|
      gy = sy.(v).round(1)
      svg << %(<line x1="#{pad[:l]}" y1="#{gy}" x2="#{pad[:l] + plot_w}" y2="#{gy}" stroke="#e2e8f0" stroke-width="1"/>)
      svg << %(<text x="#{pad[:l] - 8}" y="#{gy + 4}" font-size="11" fill="#94a3b8" text-anchor="end" style="font-variant-numeric:tabular-nums">#{usd_plain(v)}</text>)
    end

    series.each do |s|
      dash = s[:dash] ? %( stroke-dasharray="#{s[:dash]}") : ""
      unless single
        pts = coords.map { |c| "#{c[:x]},#{c[s[:key]][:y]}" }
        svg << %(<polyline points="#{pts.join(' ')}" fill="none" stroke="#{s[:color]}" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round"#{dash}/>)
      end

      coords.each do |c|
        svg << %(<circle cx="#{c[:x]}" cy="#{c[s[:key]][:y]}" r="3.5" fill="#fff" stroke="#{s[:color]}" stroke-width="2"><title>#{s[:label]} on #{c[:date]}: #{c[s[:key]][:label]}</title></circle>)
      end

      # End-of-line label, prefixed with the series name so the lines are
      # identifiable without relying on colour.
      last = coords.last[s[:key]]
      svg << %(<text x="#{(pad[:l] + plot_w + 6).round(1)}" y="#{last[:y] + 4}" font-size="12" font-weight="600" fill="#{s[:color]}">#{s[:short]} #{last[:label]}</text>)
    end

    # X-axis date labels (first + last). With a single point both collapse to one.
    if single
      svg << %(<text x="#{(pad[:l] + plot_w / 2.0).round(1)}" y="#{height - 8}" font-size="11" fill="#475569" text-anchor="middle">#{first_p.effective_on.strftime('%b %Y')}</text>)
    else
      svg << %(<text x="#{pad[:l]}" y="#{height - 8}" font-size="11" fill="#475569">#{first_p.effective_on.strftime('%b %Y')}</text>)
      svg << %(<text x="#{(pad[:l] + plot_w).round(1)}" y="#{height - 8}" font-size="11" fill="#475569" text-anchor="end">#{last_p.effective_on.strftime('%b %Y')}</text>)
    end

    # Interactive layer (hidden until the controller moves it). Crosshair line +
    # one hover marker per series. A transparent overlay on top catches pointer
    # events across the whole plot. These are inert without JS.
    svg << %(<line data-price-chart-target="crosshair" x1="0" y1="#{pad[:t]}" x2="0" y2="#{(pad[:t] + plot_h).round(1)}" stroke="#94a3b8" stroke-width="1" stroke-dasharray="3 3" visibility="hidden"/>)
    series.each do |s|
      svg << %(<circle data-price-chart-target="#{s[:target]}" cx="0" cy="0" r="4.5" fill="#{s[:color]}" stroke="#fff" stroke-width="2" visibility="hidden"/>)
    end
    # Starts inert so the data points' native <title> tooltips work without JS;
    # the controller turns pointer capture on once it connects (multi-point only).
    svg << %(<rect data-price-chart-target="overlay" data-action="pointermove->price-chart#move pointerleave->price-chart#leave pointerdown->price-chart#move" x="#{pad[:l]}" y="#{pad[:t]}" width="#{plot_w}" height="#{plot_h}" fill="#fff" fill-opacity="0" style="pointer-events:none"/>)

    svg << "</svg>"

    data_points = coords.map do |c|
      { x: c[:x], date: c[:date], input: c[:input_per_mtok], output: c[:output_per_mtok] }
    end

    content_tag(:div, class: "relative", data: {
      controller: "price-chart",
      price_chart_points_value: data_points.to_json
    }) do
      safe_join([
        svg.join.html_safe,
        content_tag(:div, "", role: "status", "aria-hidden": "true",
          class: "pointer-events-none absolute left-0 top-0 z-10 hidden whitespace-nowrap rounded-lg bg-slate-900 px-3 py-2 text-xs text-white shadow-lg",
          data: { price_chart_target: "tooltip" })
      ])
    end
  end

  # Round dollar values to draw gridlines at, from 0 up to (but not past) the
  # plot ceiling. The step is the 1/2/5 × 10ⁿ value nearest ymax/4, so labels
  # stay clean whether prices are in cents or tens of dollars.
  def chart_gridlines(ymax)
    return [ 0.0 ] if ymax <= 0

    raw = ymax / 4.0
    base = 10.0**Math.log10(raw).floor
    frac = raw / base
    step = (frac < 1.5 ? 1 : frac < 3 ? 2 : frac < 7 ? 5 : 10) * base

    (0..(ymax / step).floor).map { |i| (i * step).round(6) }
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
