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
      svg << chart_hgridline(pad[:l], pad[:l] + plot_w, sy.(v).round(1), usd_plain(v))
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

  # One horizontal gridline across the plot with its value label in the left
  # gutter. Shared by both charts (linear and log) so the axis styling — hairline
  # colour, label size/colour, gutter offset — lives in one place and can't drift.
  # `label` is already formatted; `gy` is the pre-scaled y.
  def chart_hgridline(x_left, x_right, gy, label)
    %(<line x1="#{x_left}" y1="#{gy}" x2="#{x_right}" y2="#{gy}" stroke="#e2e8f0" stroke-width="1"/>) +
      %(<text x="#{x_left - 8}" y="#{gy + 4}" font-size="11" fill="#94a3b8" text-anchor="end" style="font-variant-numeric:tabular-nums">#{label}</text>)
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

  # Multi-line step chart of every provider's flagship (most-powerful) model
  # input price over time — one stepped line per provider, drawn in the
  # provider's accent colour. Server-rendered SVG so it's identical for crawlers,
  # no-JS clients and screen readers; the flagship_chart controller only adds a
  # dim-the-rest hover highlight on top.
  #
  # The y-axis is logarithmic: flagship input prices span ~$0.15 to $75 (500×),
  # a range a linear axis would crush into a flat line near zero for all but the
  # priciest models. Decade gridlines ($0.10 / $1 / $10 / $100) keep it readable.
  #
  # `trends` is an array of FlagshipTrend, each with chronological steps.
  def provider_flagship_chart(trends, width: 900, height: 460)
    trends = trends.reject { |t| t.steps.empty? }
    if trends.empty?
      return content_tag(:p, "No flagship history on record yet.", class: "text-sm text-slate-500")
    end

    pad = { l: 48, r: 158, t: 16, b: 34 }
    plot_w = width - pad[:l] - pad[:r]
    plot_h = height - pad[:t] - pad[:b]
    x_right = pad[:l] + plot_w

    first_date = trends.flat_map { |t| t.steps.map(&:date) }.min
    xmin_t = first_date.to_time.to_i
    xmax_t = Date.current.to_time.to_i
    xspan  = [ xmax_t - xmin_t, 1 ].max
    sx = ->(date) { (pad[:l] + ((date.to_time.to_i - xmin_t).to_f / xspan) * plot_w).round(1) }

    # A log axis needs strictly-positive prices; steps are only built with a real
    # launch price, but filter defensively so a stray 0 can't reach Math.log10.
    vals = trends.flat_map { |t| t.steps.map(&:input) }.select(&:positive?)
    lo = 10.0**Math.log10(vals.min).floor
    hi = 10.0**Math.log10(vals.max).ceil
    hi = lo * 10 if hi <= lo # every price in one decade → widen so the scale can't divide by zero
    loglo, loghi = Math.log10(lo), Math.log10(hi)
    sy = ->(v) { (pad[:t] + (1 - (Math.log10(v) - loglo) / (loghi - loglo)) * plot_h).round(1) }

    uid  = "flagship-chart"
    lead = trends.max_by { |t| t.steps.size }
    desc = "#{lead.provider_name}'s flagship input price went from " \
           "#{usd_plain(lead.launch.input)} to #{usd_plain(lead.current.input)} " \
           "per 1M tokens between #{lead.launch.date.strftime('%b %Y')} and " \
           "#{lead.current.date.strftime('%b %Y')}; #{trends.size} providers shown."

    svg = []
    svg << %(<svg viewBox="0 0 #{width} #{height}" class="w-full h-auto" role="img" aria-labelledby="#{uid}-title #{uid}-desc">)
    svg << %(<title id="#{uid}-title">Provider flagship input price over time</title>)
    svg << %(<desc id="#{uid}-desc">#{ERB::Util.html_escape(desc)}</desc>)

    decade = lo
    while decade <= hi + 1e-9
      svg << chart_hgridline(pad[:l], x_right, sy.(decade), flagship_axis_price(decade))
      decade *= 10
    end

    (first_date.year..Date.current.year).each do |year|
      jan1 = Date.new(year, 1, 1)
      next if jan1 < first_date

      gx = sx.(jan1)
      svg << %(<line x1="#{gx}" y1="#{pad[:t]}" x2="#{gx}" y2="#{pad[:t] + plot_h}" stroke="#f1f5f9" stroke-width="1"/>)
      svg << %(<text x="#{gx}" y="#{height - 8}" font-size="11" fill="#94a3b8" text-anchor="middle">#{year}</text>)
    end

    # Resolve end-label positions up front so we can declutter them: labels want
    # to sit at the line's final y (`ideal`), but several flagships cluster at low
    # prices, so nudge overlapping labels apart (top-down, min 16px gap) and draw a
    # leader from the true line end to the moved label.
    label_gap = 16.0
    plot_bottom = pad[:t] + plot_h
    labels = trends.map do |t|
      y0 = sy.(t.current.input).to_f
      { trend: t, y: y0, ideal: y0 }
    end.sort_by { |l| l[:y] }
    prev = -Float::INFINITY
    labels.each do |l|
      l[:y] = [ l[:y], prev + label_gap ].max
      prev = l[:y]
    end
    # A tall low-price cluster can push the last labels past the plot; shift the
    # whole run up by the overflow (clamped to the top) so none clip off-canvas.
    overflow = labels.any? ? labels.last[:y] - plot_bottom : 0
    labels.each { |l| l[:y] = [ l[:y] - overflow, pad[:t].to_f ].max } if overflow.positive?

    # One stepped line per provider. A step holds the old price to the next
    # release date, then jumps — a price is a step function, not a slope — and the
    # final segment extends flat to today at the current flagship price.
    trends.each do |t|
      pts = t.steps.map { |s| [ sx.(s.date), sy.(s.input) ] }
      d = +"M#{pts.first[0]},#{pts.first[1]}"
      pts.each_cons(2) { |(_, prev_y), (x, y)| d << " L#{x},#{prev_y} L#{x},#{y}" }
      d << " L#{x_right},#{pts.last[1]}"

      svg << %(<g class="flagship-line" data-provider="#{t.provider_slug}" data-action="mouseenter->flagship-chart#highlight mouseleave->flagship-chart#reset">)
      svg << %(<path d="#{d}" fill="none" stroke="#{t.accent}" stroke-width="2.25" stroke-linejoin="round" stroke-linecap="round"/>)
      t.steps.zip(pts).each do |s, (cx, cy)|
        svg << %(<circle cx="#{cx}" cy="#{cy}" r="3.25" fill="#fff" stroke="#{t.accent}" stroke-width="2"><title>#{ERB::Util.html_escape("#{t.provider_name} — #{s.model_name}, #{s.date.strftime('%b %Y')}: #{usd_plain(s.input)} in / #{usd_plain(s.output)} out per 1M")}</title></circle>)
      end
      svg << "</g>"
    end

    labels.each do |l|
      t = l[:trend]
      ly = l[:y].round(1)
      if (l[:y] - l[:ideal]).abs > 1
        svg << %(<line x1="#{x_right}" y1="#{l[:ideal].round(1)}" x2="#{x_right + 8}" y2="#{ly}" stroke="#{t.accent}" stroke-width="1" opacity="0.4"/>)
      end
      svg << %(<text class="flagship-endlabel" data-provider="#{t.provider_slug}" x="#{x_right + 11}" y="#{ly + 4}" font-size="12" font-weight="600" fill="#{t.accent}">#{ERB::Util.html_escape(t.provider_name)} <tspan fill="#64748b" font-weight="500">#{flagship_axis_price(t.current.input)}</tspan></text>)
    end

    svg << "</svg>"

    content_tag(:div, svg.join.html_safe, class: "flagship-chart")
  end

  # Compact dollar label for the flagship chart's axis and end labels: whole
  # dollars drop the ".00" ($30, not $30.00), sub-dollar keeps significant
  # digits ($0.15). usd_plain always shows 2dp above $1, which reads noisy here.
  def flagship_axis_price(value)
    v = value.to_f
    return "$#{v.round}" if v >= 1 && (v - v.round).abs < 0.005

    usd_plain(v)
  end

  def chart_legend
    safe_join([
      content_tag(:span, "Input (solid)", class: "inline-flex items-center gap-1.5 text-xs font-medium text-slate-600 before:h-2 before:w-2 before:rounded-full before:bg-indigo-600 before:content-['']"),
      content_tag(:span, "Output (dashed)", class: "inline-flex items-center gap-1.5 text-xs font-medium text-slate-600 before:h-2 before:w-2 before:rounded-full before:bg-rose-600 before:content-['']")
    ], tag.span(class: "mx-3"))
  end
end
