import { Controller } from "@hotwired/stimulus"

// ── Palette ─────────────────────────────────────────────────────────────────
const PALETTE = [
  "#4f46e5","#0ea5e9","#059669","#f59e0b","#e11d48",
  "#7c3aed","#0891b2","#c2683f","#1c5bd6","#db5a18"
]

// ── Presets ──────────────────────────────────────────────────────────────────
const PRESETS = {
  "anthropic-vs-openai": {
    label: "Anthropic vs OpenAI",
    filter: m => (m.provider === "anthropic" || m.provider === "openai") && m.tier === "frontier"
  },
  "frontier": {
    label: "All frontier",
    filter: m => m.tier === "frontier"
  },
  "budget": {
    label: "Budget tier",
    filter: m => m.tier === "small"
  },
  "the-cuts": {
    label: "Biggest price cuts",
    filter: m => m.history.length > 1
  }
}

// ── SVG helpers ──────────────────────────────────────────────────────────────
const SVG_NS = "http://www.w3.org/2000/svg"
function svgEl(tag, attrs = {}) {
  const el = document.createElementNS(SVG_NS, tag)
  for (const [k, v] of Object.entries(attrs)) el.setAttribute(k, v)
  return el
}

// ── Date helpers ─────────────────────────────────────────────────────────────
function parseDate(s) { return new Date(s + "T00:00:00Z") }
function fmtMonthYear(d) {
  return d.toLocaleDateString("en-US", { month: "short", year: "numeric", timeZone: "UTC" })
}
function fmtDateFull(d) {
  return d.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric", timeZone: "UTC" })
}

// ── Price formatter ──────────────────────────────────────────────────────────
function fmtPrice(v) {
  if (v == null) return "—"
  if (v === 0) return "$0"
  if (v < 1) return "$" + parseFloat(v.toFixed(4)).toString()
  return "$" + v.toFixed(2)
}

// ── Log tick generation ───────────────────────────────────────────────────────
function logTicks(minV, maxV) {
  const ticks = []
  const magnitudes = [-4, -3, -2, -1, 0, 1, 2, 3, 4]
  const multipliers = [1, 2, 5]
  for (const mag of magnitudes) {
    for (const mul of multipliers) {
      const v = mul * Math.pow(10, mag)
      if (v >= minV * 0.5 && v <= maxV * 2) ticks.push(v)
    }
  }
  return [...new Set(ticks)].sort((a, b) => a - b)
}

// ── Linear tick generation ────────────────────────────────────────────────────
function linearTicks(minV, maxV, count = 6) {
  const range = maxV - minV
  if (range < 1e-12) {
    if (minV === 0) return [0, 0.5, 1]
    return [minV * 0.5, minV, minV * 1.5]
  }
  const rawStep = range / (count - 1)
  const mag = Math.pow(10, Math.floor(Math.log10(rawStep)))
  const step = Math.ceil(rawStep / mag) * mag
  const start = Math.floor(minV / step) * step
  const ticks = []
  for (let v = start; v <= maxV + step * 0.01; v += step) {
    if (v >= minV * 0.5) ticks.push(parseFloat(v.toPrecision(6)))
  }
  return ticks
}

// ── Controller ────────────────────────────────────────────────────────────────
export default class extends Controller {
  static targets = [
    "presetList",
    "selCount",
    "modelList",
    "chartArea",
    "svg",
    "emptyState",
    "tooltip",
    "legend",
    "eventsToggle",
    "eventsPopoverWrap",
    "eventsPopoverBtn",
    "eventsPopover",
    "eventsPopoverList",
    "scaleSeg"
  ]

  static values = {
    models: { type: Array, default: [] },
    events: { type: Array, default: [] }
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────────
  connect() {
    this.selected = new Map()   // slug → color
    this.metric = "blended"
    this.scale = "log"
    this.showEvents = true
    this.activePreset = null
    this._paletteIdx = 0
    this._flashTimeout = null

    this._boundOutside = this._onOutsideClick.bind(this)
    document.addEventListener("click", this._boundOutside, true)

    this._buildModelList()
    this._buildEventsPopover()
    this._applyPreset("anthropic-vs-openai")
  }

  disconnect() {
    document.removeEventListener("click", this._boundOutside, true)
    clearTimeout(this._flashTimeout)
  }

  // ── Preset selection ─────────────────────────────────────────────────────────
  selectPreset(event) {
    const btn = event.currentTarget
    const presetKey = btn.dataset.preset
    this._applyPreset(presetKey)
  }

  _applyPreset(key) {
    const preset = PRESETS[key]
    if (!preset) return

    this.activePreset = key
    this.selected.clear()
    this._paletteIdx = 0

    const matching = this.modelsValue.filter(preset.filter)
    // Limit to palette size
    matching.slice(0, PALETTE.length).forEach(m => {
      this.selected.set(m.slug, PALETTE[this._paletteIdx++ % PALETTE.length])
    })

    this._syncPresetButtons()
    this._syncModelList()
    this._syncSelCount()
    this._render()
  }

  _syncPresetButtons() {
    if (!this.hasPresetListTarget) return
    this.presetListTarget.querySelectorAll(".trends-preset-btn").forEach(btn => {
      btn.classList.toggle("active", btn.dataset.preset === this.activePreset)
    })
  }

  // ── Model list ───────────────────────────────────────────────────────────────
  _buildModelList() {
    if (!this.hasModelListTarget) return

    const models = this.modelsValue
    const byProvider = new Map()
    models.forEach(m => {
      if (!byProvider.has(m.provider_name)) byProvider.set(m.provider_name, [])
      byProvider.get(m.provider_name).push(m)
    })

    const frag = document.createDocumentFragment()
    for (const [provName, provModels] of byProvider) {
      const header = document.createElement("div")
      header.className = "trends-group-header"
      header.textContent = provName
      frag.appendChild(header)

      provModels.forEach(m => {
        const row = document.createElement("button")
        row.className = "trends-model-row"
        row.dataset.slug = m.slug
        row.setAttribute("data-action", "click->trends-chart#toggleModel")

        const swatch = document.createElement("span")
        swatch.className = "trends-swatch"
        swatch.dataset.swatchSlug = m.slug

        const name = document.createElement("span")
        name.className = "trends-model-name"
        name.textContent = m.name

        const price = document.createElement("span")
        price.className = "trends-model-price"
        const lastPp = m.history[m.history.length - 1]
        if (lastPp) {
          price.textContent = fmtPrice(lastPp.input) + " / " + fmtPrice(lastPp.output)
        }

        row.appendChild(swatch)
        row.appendChild(name)
        row.appendChild(price)
        frag.appendChild(row)
      })
    }

    this.modelListTarget.innerHTML = ""
    this.modelListTarget.appendChild(frag)
  }

  _syncModelList() {
    if (!this.hasModelListTarget) return
    this.modelListTarget.querySelectorAll(".trends-model-row").forEach(row => {
      const slug = row.dataset.slug
      const color = this.selected.get(slug)
      const swatch = row.querySelector(".trends-swatch")
      if (color) {
        swatch.style.background = color
        swatch.style.boxShadow = "none"
        row.style.opacity = "1"
      } else {
        swatch.style.background = "transparent"
        swatch.style.boxShadow = `0 0 0 2px ${this._swatchRingColor(slug)}`
        row.style.opacity = "0.7"
      }
    })
  }

  _swatchRingColor(slug) {
    // Reuse a stable ring color per model position
    const idx = this.modelsValue.findIndex(m => m.slug === slug)
    return PALETTE[idx % PALETTE.length]
  }

  toggleModel(event) {
    const btn = event.currentTarget
    const slug = btn.dataset.slug

    if (this.selected.has(slug)) {
      this.selected.delete(slug)
    } else {
      if (this.selected.size >= PALETTE.length) return // palette exhausted
      const usedColors = new Set(this.selected.values())
      const color = PALETTE.find(c => !usedColors.has(c)) || PALETTE[0]
      this.selected.set(slug, color)
    }

    // Selecting a model manually clears the active preset
    this.activePreset = null
    this._syncPresetButtons()
    this._syncModelList()
    this._syncSelCount()
    this._render()
  }

  _syncSelCount() {
    if (!this.hasSelCountTarget) return
    const n = this.selected.size
    const span = this.selCountTarget.querySelector(".trends-sel-n")
    if (span) span.textContent = n
  }

  // ── Toolbar actions ──────────────────────────────────────────────────────────
  setMetric(event) {
    const btn = event.currentTarget
    const metric = btn.dataset.metric
    this.metric = metric
    btn.closest(".tp-seg").querySelectorAll("button").forEach(b => {
      b.classList.toggle("on", b.dataset.metric === metric)
    })
    this._render()
  }

  setScale(event) {
    const btn = event.currentTarget
    const scale = btn.dataset.scale
    this.scale = scale
    if (this.hasScaleSegTarget) {
      this.scaleSegTarget.querySelectorAll("button").forEach(b => {
        b.classList.toggle("on", b.dataset.scale === scale)
      })
    }
    this._render()
  }

  toggleEvents(event) {
    this.showEvents = !this.showEvents
    const btn = event.currentTarget
    btn.classList.toggle("on", this.showEvents)
    btn.setAttribute("aria-checked", this.showEvents ? "true" : "false")
    this._render()
  }

  toggleEventsPopover(event) {
    event.stopPropagation()
    if (!this.hasEventsPopoverTarget) return
    this.eventsPopoverTarget.classList.toggle("open")
  }

  _onOutsideClick(event) {
    if (!this.hasEventsPopoverWrapTarget) return
    if (!this.eventsPopoverWrapTarget.contains(event.target)) {
      this.eventsPopoverTarget?.classList.remove("open")
    }
  }

  // ── Events popover ───────────────────────────────────────────────────────────
  _buildEventsPopover() {
    if (!this.hasEventsPopoverListTarget) return

    this.eventsPopoverListTarget.textContent = ""

    const marketEvents = this.eventsValue
      .filter(e => e.kind === "market")
      .slice()
      .sort((a, b) => b.date.localeCompare(a.date)) // newest first

    const frag = document.createDocumentFragment()
    marketEvents.forEach(ev => {
      const row = document.createElement("div")
      row.className = "trends-event-row"
      row.dataset.eventDate = ev.date
      row.addEventListener("click", () => this._flashEvent(ev.date))

      const date = document.createElement("div")
      date.className = "trends-event-date"
      date.textContent = fmtDateFull(parseDate(ev.date))

      const title = document.createElement("div")
      title.className = "trends-event-title"
      title.textContent = ev.title

      if (ev.note) {
        const note = document.createElement("div")
        note.className = "trends-event-note"
        note.textContent = ev.note
        row.appendChild(date)
        row.appendChild(title)
        row.appendChild(note)
      } else {
        row.appendChild(date)
        row.appendChild(title)
      }

      frag.appendChild(row)
    })

    this.eventsPopoverListTarget.appendChild(frag)
  }

  _flashEvent(dateStr) {
    // Close popover
    this.eventsPopoverTarget?.classList.remove("open")

    // Find and flash the event line in the SVG
    if (!this.hasSvgTarget) return
    const lines = this.svgTarget.querySelectorAll(`[data-event-date="${dateStr}"]`)
    clearTimeout(this._flashTimeout)
    lines.forEach(el => {
      el.style.transition = "none"
      el.style.opacity = "1"
      el.style.strokeWidth = "3"
    })
    this._flashTimeout = setTimeout(() => {
      lines.forEach(el => {
        el.style.transition = "stroke-width 0.4s, opacity 0.4s"
        el.style.strokeWidth = ""
        el.style.opacity = ""
      })
    }, 600)
  }

  // ── Chart rendering ──────────────────────────────────────────────────────────
  _render() {
    if (!this.hasSvgTarget || !this.hasChartAreaTarget) return

    const selectedSlugs = [...this.selected.keys()]

    if (selectedSlugs.length === 0) {
      this.emptyStateTarget?.classList.add("visible")
      this.svgTarget.classList.add("hidden")
      if (this.hasLegendTarget) this.legendTarget.innerHTML = ""
      return
    }

    this.emptyStateTarget?.classList.remove("visible")
    this.svgTarget.classList.remove("hidden")

    const models = this.modelsValue.filter(m => this.selected.has(m.slug))
    const events = this.showEvents ? this.eventsValue : []

    // ── Chart dimensions ────────────────────────────────────────────────────
    const VW = 880, VH = 380
    const PAD = { top: 22, right: 28, bottom: 46, left: 62 }
    const plotW = VW - PAD.left - PAD.right
    const plotH = VH - PAD.top - PAD.bottom

    // ── Build series data ───────────────────────────────────────────────────
    const today = new Date()
    today.setUTCHours(0, 0, 0, 0)

    const series = models.map(m => {
      const color = this.selected.get(m.slug)
      const pts = m.history
        .slice()
        .sort((a, b) => a.date.localeCompare(b.date))
        .map(pp => ({
          date: parseDate(pp.date),
          value: this._metricValue(pp)
        }))
        .filter(pt => pt.value != null && pt.value > 0)

      // Extend to today
      if (pts.length > 0) {
        const last = pts[pts.length - 1]
        if (last.date < today) {
          pts.push({ date: today, value: last.value, isNow: true })
        } else {
          pts[pts.length - 1].isNow = true
        }
      }

      return { model: m, color, pts }
    }).filter(s => s.pts.length > 0)

    if (series.length === 0) {
      this.emptyStateTarget?.classList.add("visible")
      this.svgTarget.classList.add("hidden")
      return
    }

    // ── X domain ───────────────────────────────────────────────────────────
    let xMin = series.reduce((acc, s) => {
      const d = s.pts[0]?.date
      return d && d < acc ? d : acc
    }, today)
    const xMax = today

    // Pad left by 30 days
    xMin = new Date(xMin.getTime() - 30 * 86400000)

    const xRange = xMax - xMin

    function xPos(date) {
      return PAD.left + ((date - xMin) / xRange) * plotW
    }

    // ── Y domain ───────────────────────────────────────────────────────────
    const allValues = series.flatMap(s => s.pts.map(p => p.value)).filter(v => v > 0)
    let yMin = Math.min(...allValues)
    let yMax = Math.max(...allValues)

    // Padding
    if (this.scale === "log") {
      yMin = yMin / 2
      yMax = yMax * 2
    } else {
      const pad = (yMax - yMin) * 0.1 || yMax * 0.1
      yMin = Math.max(0, yMin - pad)
      yMax = yMax + pad
    }

    const yPos = (v) => {
      if (this.scale === "log") {
        const lMin = Math.log10(yMin)
        const lMax = Math.log10(yMax)
        return PAD.top + (1 - (Math.log10(v) - lMin) / (lMax - lMin)) * plotH
      } else {
        return PAD.top + (1 - (v - yMin) / (yMax - yMin)) * plotH
      }
    }

    // ── Build SVG ──────────────────────────────────────────────────────────
    const svg = this.svgTarget
    svg.innerHTML = ""
    svg.setAttribute("viewBox", `0 0 ${VW} ${VH}`)

    // Defs (clip path)
    const defs = svgEl("defs")
    const clip = svgEl("clipPath", { id: "plot-clip" })
    clip.appendChild(svgEl("rect", {
      x: PAD.left, y: PAD.top,
      width: plotW, height: plotH
    }))
    defs.appendChild(clip)
    svg.appendChild(defs)

    // Plot area group
    const plotG = svgEl("g", { "clip-path": "url(#plot-clip)" })
    svg.appendChild(plotG)

    // ── Grid lines & Y axis ───────────────────────────────────────────────
    const yTicks = this.scale === "log"
      ? logTicks(yMin, yMax)
      : linearTicks(yMin, yMax)

    const axisG = svgEl("g")
    svg.appendChild(axisG) // unclipped so labels show

    yTicks.forEach(tick => {
      const y = yPos(tick)
      if (y < PAD.top - 2 || y > PAD.top + plotH + 2) return

      // Grid line (clipped)
      const gl = svgEl("line", {
        x1: PAD.left, x2: PAD.left + plotW,
        y1: y, y2: y,
        stroke: "var(--color-slate-100)",
        "stroke-width": "1"
      })
      plotG.appendChild(gl)

      // Label
      const label = svgEl("text", {
        x: PAD.left - 6,
        y: y + 4,
        "text-anchor": "end",
        fill: "var(--color-slate-400)",
        "font-family": "JetBrains Mono, monospace",
        "font-size": "10",
        "font-weight": "600"
      })
      label.textContent = "$" + this._tickLabel(tick)
      axisG.appendChild(label)
    })

    // ── X axis ticks ─────────────────────────────────────────────────────
    const xTicks = this._monthTicks(xMin, xMax)
    xTicks.forEach(d => {
      const x = xPos(d)
      if (x < PAD.left || x > PAD.left + plotW) return

      const gl = svgEl("line", {
        x1: x, x2: x,
        y1: PAD.top, y2: PAD.top + plotH,
        stroke: "var(--color-slate-100)",
        "stroke-width": "1"
      })
      plotG.appendChild(gl)

      const label = svgEl("text", {
        x: x,
        y: PAD.top + plotH + 16,
        "text-anchor": "middle",
        fill: "var(--color-slate-400)",
        "font-family": "JetBrains Mono, monospace",
        "font-size": "9.5"
      })
      label.textContent = d.toLocaleDateString("en-US", { month: "short", year: "2-digit", timeZone: "UTC" })
      axisG.appendChild(label)
    })

    // ── Axis border ───────────────────────────────────────────────────────
    axisG.appendChild(svgEl("line", {
      x1: PAD.left, x2: PAD.left + plotW,
      y1: PAD.top + plotH, y2: PAD.top + plotH,
      stroke: "var(--color-slate-200)", "stroke-width": "1"
    }))
    axisG.appendChild(svgEl("line", {
      x1: PAD.left, x2: PAD.left,
      y1: PAD.top, y2: PAD.top + plotH,
      stroke: "var(--color-slate-200)", "stroke-width": "1"
    }))

    // ── Event overlays ────────────────────────────────────────────────────
    const eventsG = svgEl("g", { "clip-path": "url(#plot-clip)" })
    if (this.showEvents) {
      events.forEach(ev => {
        const d = parseDate(ev.date)
        if (d < xMin || d > xMax) return
        const x = xPos(d)
        const isMarket = ev.kind === "market"
        const color = isMarket ? "#e11d48" : "#94a3b8"

        const line = svgEl("line", {
          x1: x, x2: x,
          y1: PAD.top, y2: PAD.top + plotH,
          stroke: color,
          "stroke-width": "1.5",
          "stroke-dasharray": "4 3",
          opacity: isMarket ? "0.7" : "0.45",
          "data-event-date": ev.date,
          style: "cursor:pointer"
        })
        eventsG.appendChild(line)

        // Flag dot at top for market events
        if (isMarket) {
          const dot = svgEl("circle", {
            cx: x, cy: PAD.top + 4,
            r: "4",
            fill: color,
            opacity: "0.8",
            "data-event-date": ev.date
          })
          eventsG.appendChild(dot)
        }

        // Invisible wide hit target for hover tooltip
        const hit = svgEl("line", {
          x1: x, x2: x,
          y1: PAD.top, y2: PAD.top + plotH,
          stroke: "transparent",
          "stroke-width": "14",
          style: "cursor:pointer",
          "data-event-date": ev.date,
          "data-event-title": ev.title,
          "data-event-kind": ev.kind,
          "data-event-note": ev.note || ""
        })
        hit.addEventListener("mouseenter", (e) => this._showEventTooltip(e, ev))
        hit.addEventListener("mouseleave", () => this._hideTooltip())
        eventsG.appendChild(hit)
      })
    }
    svg.appendChild(eventsG)

    // ── Series lines + dots ───────────────────────────────────────────────
    const linesG = svgEl("g", { "clip-path": "url(#plot-clip)" })

    series.forEach(({ model: m, color, pts }) => {
      if (pts.length === 0) return

      // Build stepwise path
      let d = ""
      pts.forEach((pt, i) => {
        const x = xPos(pt.date)
        const y = yPos(pt.value)
        if (i === 0) {
          d += `M ${x} ${y}`
        } else {
          // Horizontal then vertical (step-after style, but reversed for price chart)
          const prevX = xPos(pts[i - 1].date)
          d += ` H ${x} V ${y}`
        }
      })

      const path = svgEl("path", {
        d,
        fill: "none",
        stroke: color,
        "stroke-width": "2.5",
        "stroke-linecap": "round",
        "stroke-linejoin": "round"
      })

      // Draw-in animation
      const len = this._approxPathLength(pts, xPos, yPos)
      path.style.strokeDasharray = len
      path.style.strokeDashoffset = len
      path.style.transition = `stroke-dashoffset 0.9s cubic-bezier(0.4,0,0.2,1)`
      linesG.appendChild(path)

      // Trigger animation
      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          path.style.strokeDashoffset = "0"
        })
      })

      // White dots at real price points (not the "now" extension)
      pts.forEach((pt, i) => {
        if (i === pts.length - 1 && pt.isNow && pts.length > 1) {
          // Terminal dot (filled with color)
          const dot = svgEl("circle", {
            cx: xPos(pt.date),
            cy: yPos(pt.value),
            r: "4",
            fill: color,
            stroke: "#fff",
            "stroke-width": "2"
          })
          linesG.appendChild(dot)
        } else if (!pt.isNow) {
          // Real price point: white dot with color ring
          const dot = svgEl("circle", {
            cx: xPos(pt.date),
            cy: yPos(pt.value),
            r: "3.5",
            fill: "#fff",
            stroke: color,
            "stroke-width": "2"
          })
          linesG.appendChild(dot)
        }
      })
    })

    svg.appendChild(linesG)

    // ── Crosshair overlay ────────────────────────────────────────────────
    const crosshairG = svgEl("g", { "pointer-events": "none" })
    const crosshairLine = svgEl("line", {
      y1: PAD.top, y2: PAD.top + plotH,
      stroke: "var(--color-slate-300)",
      "stroke-width": "1",
      "stroke-dasharray": "4 3",
      opacity: "0",
      style: "transition: opacity .1s"
    })
    crosshairG.appendChild(crosshairLine)
    svg.appendChild(crosshairG)

    // ── Mouse interaction ─────────────────────────────────────────────────
    const overlay = svgEl("rect", {
      x: PAD.left, y: PAD.top,
      width: plotW, height: plotH,
      fill: "transparent",
      style: "cursor:crosshair"
    })

    overlay.addEventListener("mousemove", (e) => {
      const rect = svg.getBoundingClientRect()
      const scaleX = VW / rect.width
      const mx = (e.clientX - rect.left) * scaleX
      const date = new Date(xMin.getTime() + ((mx - PAD.left) / plotW) * xRange)

      crosshairLine.setAttribute("x1", mx)
      crosshairLine.setAttribute("x2", mx)
      crosshairLine.style.opacity = "1"

      this._showCrosshairTooltip(e, date, series)
    })

    overlay.addEventListener("mouseleave", () => {
      crosshairLine.style.opacity = "0"
      this._hideTooltip()
    })

    svg.appendChild(overlay)

    // ── Legend ──────────────────────────────────────────────────────────
    this._renderLegend(series)
  }

  _metricValue(pp) {
    if (this.metric === "input") return pp.input
    if (this.metric === "output") return pp.output
    // blended: (3 * input + output) / 4
    if (pp.input == null || pp.output == null) return null
    return (3 * pp.input + pp.output) / 4
  }

  _tickLabel(v) {
    if (v >= 1000) return (v / 1000).toFixed(0) + "k"
    if (v >= 1) return v.toFixed(v % 1 === 0 ? 0 : 2)
    if (v >= 0.01) return v.toFixed(2).replace(/0+$/, "").replace(/\.$/, "")
    return v.toFixed(4).replace(/0+$/, "").replace(/\.$/, "")
  }

  _monthTicks(xMin, xMax) {
    const ticks = []
    const d = new Date(Date.UTC(xMin.getUTCFullYear(), xMin.getUTCMonth(), 1))
    while (d <= xMax) {
      ticks.push(new Date(d))
      d.setUTCMonth(d.getUTCMonth() + 1)
    }
    // Thin out if too many
    if (ticks.length > 20) {
      return ticks.filter((_, i) => i % 3 === 0)
    } else if (ticks.length > 10) {
      return ticks.filter((_, i) => i % 2 === 0)
    }
    return ticks
  }

  _approxPathLength(pts, xPos, yPos) {
    let len = 0
    for (let i = 1; i < pts.length; i++) {
      const dx = xPos(pts[i].date) - xPos(pts[i - 1].date)
      const dy = yPos(pts[i].value) - yPos(pts[i - 1].value)
      // Stepwise path: horizontal + vertical
      len += Math.abs(dx) + Math.abs(dy)
    }
    return Math.max(len, 10)
  }

  // ── Tooltip helpers ──────────────────────────────────────────────────────────
  _showCrosshairTooltip(mouseEvent, date, series) {
    if (!this.hasTooltipTarget) return

    const tip = this.tooltipTarget
    const rows = series.map(({ model: m, color, pts }) => {
      // Find the price at date (step-wise: last point before or at date)
      const pp = pts.filter(p => p.date <= date).pop()
      const val = pp ? pp.value : null
      return { name: m.name, color, val }
    })

    tip.textContent = ""
    const dateDiv = document.createElement("div")
    dateDiv.className = "trends-tooltip-date"
    dateDiv.textContent = fmtDateFull(date)
    tip.appendChild(dateDiv)

    rows.forEach(r => {
      const row = document.createElement("div")
      row.className = "trends-tooltip-row"

      const dot = document.createElement("span")
      dot.className = "trends-tooltip-dot"
      dot.style.background = r.color

      const name = document.createElement("span")
      name.className = "trends-tooltip-name"
      name.textContent = r.name

      const price = document.createElement("span")
      price.className = "trends-tooltip-price"
      price.textContent = fmtPrice(r.val) + "/M"

      row.appendChild(dot)
      row.appendChild(name)
      row.appendChild(price)
      tip.appendChild(row)
    })
    this._positionTooltip(mouseEvent)
    tip.classList.add("visible")
  }

  _showEventTooltip(mouseEvent, ev) {
    if (!this.hasTooltipTarget) return
    const tip = this.tooltipTarget
    const kindLabel = ev.kind === "market" ? "Market event" : "Model launch"
    tip.textContent = ""

    const dateDiv = document.createElement("div")
    dateDiv.className = "trends-tooltip-date"
    dateDiv.style.color = ev.kind === "market" ? "#fb7185" : "rgba(255,255,255,.5)"
    dateDiv.textContent = kindLabel + " · " + fmtDateFull(parseDate(ev.date))
    tip.appendChild(dateDiv)

    const titleDiv = document.createElement("div")
    Object.assign(titleDiv.style, { fontWeight: "600", color: "#fff", fontSize: "12.5px", marginBottom: ev.note ? "4px" : "0" })
    titleDiv.textContent = ev.title
    tip.appendChild(titleDiv)

    if (ev.note) {
      const noteDiv = document.createElement("div")
      Object.assign(noteDiv.style, { fontSize: "11.5px", color: "rgba(255,255,255,.65)", lineHeight: "1.45" })
      noteDiv.textContent = ev.note
      tip.appendChild(noteDiv)
    }
    this._positionTooltip(mouseEvent)
    tip.classList.add("visible")
  }

  _positionTooltip(mouseEvent) {
    if (!this.hasTooltipTarget || !this.hasChartAreaTarget) return
    const tip = this.tooltipTarget
    const area = this.chartAreaTarget.getBoundingClientRect()
    const tipW = 230
    const tipH = tip.offsetHeight || 80
    let left = mouseEvent.clientX - area.left + 14
    let top = mouseEvent.clientY - area.top - tipH / 2

    if (left + tipW > area.width - 8) left = mouseEvent.clientX - area.left - tipW - 14
    if (top < 4) top = 4
    if (top + tipH > area.height - 4) top = area.height - tipH - 4

    tip.style.left = left + "px"
    tip.style.top = top + "px"
  }

  _hideTooltip() {
    this.tooltipTarget?.classList.remove("visible")
  }

  // ── Legend ───────────────────────────────────────────────────────────────────
  _renderLegend(series) {
    if (!this.hasLegendTarget) return

    const frag = document.createDocumentFragment()

    series.forEach(({ model: m, color }) => {
      const item = document.createElement("span")
      item.className = "trends-legend-item"
      const line = document.createElement("span")
      line.className = "trends-legend-line"
      line.style.background = color
      item.appendChild(line)
      item.appendChild(document.createTextNode(m.name))
      frag.appendChild(item)
    })

    if (this.showEvents) {
      const marketEvents = this.eventsValue.filter(e => e.kind === "market")
      const launchEvents = this.eventsValue.filter(e => e.kind === "launch")
      if (marketEvents.length) {
        const item = document.createElement("span")
        item.className = "trends-legend-item"
        const dash = document.createElement("span")
        dash.className = "trends-legend-dash"
        dash.style.borderColor = "#e11d48"
        item.appendChild(dash)
        item.appendChild(document.createTextNode("Market event"))
        frag.appendChild(item)
      }
      if (launchEvents.length) {
        const item = document.createElement("span")
        item.className = "trends-legend-item"
        const dash = document.createElement("span")
        dash.className = "trends-legend-dash"
        dash.style.borderColor = "#94a3b8"
        item.appendChild(dash)
        item.appendChild(document.createTextNode("Model launch"))
        frag.appendChild(item)
      }
    }

    this.legendTarget.textContent = ""
    this.legendTarget.appendChild(frag)
  }
}
