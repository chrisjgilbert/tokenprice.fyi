import { Controller } from "@hotwired/stimulus"

// ── Palette ─────────────────────────────────────────────────────────────────
const PALETTE = [
  "#4f46e5","#0ea5e9","#059669","#f59e0b","#e11d48",
  "#7c3aed","#0891b2","#c2683f","#1c5bd6","#db5a18"
]

const METRIC_LABEL = { blended: "I/O avg", input: "Input", output: "Output" }

// ── Presets ──────────────────────────────────────────────────────────────────
const PRESETS = {
  "frontier": {
    label: "All frontier",
    filter: m => m.tier === "frontier"
  },
  "anthropic-vs-openai": {
    label: "Anthropic vs OpenAI",
    filter: m => (m.provider === "anthropic" || m.provider === "openai") && m.tier === "frontier"
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
const DAY = 86400000
function parseDateUTC(iso) {
  const [y, m, d] = iso.split("-").map(Number)
  return Date.UTC(y, m - 1, d)
}
function fmtAxisDate(t) {
  const d = new Date(t)
  const months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
  return months[d.getUTCMonth()] + " '" + String(d.getUTCFullYear()).slice(2)
}
function fmtDateFullFromISO(iso) {
  const [y, m, d] = iso.split("-").map(Number)
  const months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
  return months[m - 1] + " " + d + ", " + y
}

// ── HTML escape ──────────────────────────────────────────────────────────────
function esc(s) {
  const el = document.createElement("span")
  el.textContent = s
  return el.innerHTML
}

// ── Price formatter ──────────────────────────────────────────────────────────
function fmtPrice(v) {
  if (v == null) return "—"
  if (v === 0) return "$0"
  if (v < 1) return "$" + parseFloat(v.toFixed(4)).toString()
  return "$" + v.toFixed(2)
}

// ── Linear nice ticks (from 0) ──────────────────────────────────────────────
function niceStep(range, count) {
  const raw = range / count
  const mag = Math.pow(10, Math.floor(Math.log10(raw)))
  const n = raw / mag
  let s
  if (n < 1.5) s = 1
  else if (n < 3) s = 2
  else if (n < 7) s = 5
  else s = 10
  return s * mag
}

function linNice(max) {
  if (!(max > 0)) max = 1
  const step = niceStep(max, 5)
  const top = Math.ceil((max * 1.06) / step) * step
  const ticks = []
  for (let v = 0; v <= top + 1e-9; v += step) ticks.push(+v.toFixed(6))
  return { top, ticks }
}

function fmtMoney(v) {
  if (v === 0) return "0"
  if (v >= 10) return String(Math.round(v))
  if (v >= 1) return (v % 1 ? v.toFixed(1) : String(v))
  return v.toFixed(2).replace(/0+$/, "").replace(/\.$/, "")
}

function monthTicks(tMin, tMax) {
  const out = []
  const months = (tMax - tMin) / (DAY * 30.4)
  const stepM = months <= 8 ? 2 : months <= 16 ? 3 : months <= 28 ? 4 : 6
  let d = new Date(tMin)
  d = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), 1))
  while (d.getTime() < tMax) {
    const t = d.getTime()
    if (t >= tMin) out.push(t)
    d = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + stepM, 1))
  }
  return out
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
    "eventTooltip",
    "legend",
    "eventsToggle",
    "eventsPopoverWrap",
    "eventsPopoverBtn",
    "eventsPopover",
    "eventsPopoverList"
  ]

  static values = {
    models: { type: Array, default: [] },
    events: { type: Array, default: [] }
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────────
  connect() {
    this.selected = new Map()   // slug → color
    this.metric = "blended"
    this.showEvents = true
    this.activePreset = null
    this._paletteIdx = 0

    this._boundOutside = this._onOutsideClick.bind(this)
    document.addEventListener("click", this._boundOutside, true)

    this._buildModelList()
    this._buildEventsPopover()
    this._applyPreset("frontier")
  }

  disconnect() {
    document.removeEventListener("click", this._boundOutside, true)
  }

  // ── Preset selection ─────────────────────────────────────────────────────────
  selectPreset(event) {
    const btn = event.currentTarget
    this._applyPreset(btn.dataset.preset)
  }

  _applyPreset(key) {
    const preset = PRESETS[key]
    if (!preset) return

    this.activePreset = key
    this.selected.clear()
    this._paletteIdx = 0

    const matching = this.modelsValue.filter(preset.filter)
    matching.slice(0, PALETTE.length).forEach(m => {
      this.selected.set(m.slug, PALETTE[this._paletteIdx++ % PALETTE.length])
    })

    this._syncPresetButtons()
    this._syncModelList()
    this._syncSelCount()
    this._render(true)
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
        row.dataset.on = "false"
        row.setAttribute("data-action", "click->trends-chart#toggleModel")

        const swatch = document.createElement("span")
        swatch.className = "trends-swatch"

        const name = document.createElement("span")
        name.className = "trends-model-name"
        name.textContent = m.name

        const price = document.createElement("span")
        price.className = "trends-model-price"
        const lastPp = m.history[m.history.length - 1]
        if (lastPp) {
          price.innerHTML = fmtPrice(lastPp.input) + '<span style="color:var(--color-slate-300)">/</span>' + fmtPrice(lastPp.output)
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
      const on = this.selected.has(slug)
      row.dataset.on = on ? "true" : "false"
      if (on) {
        swatch.style.background = color
        swatch.style.borderColor = "transparent"
        swatch.style.border = "none"
      } else {
        swatch.style.background = "transparent"
        swatch.style.border = "2px solid var(--color-slate-300)"
      }
    })
  }

  toggleModel(event) {
    const btn = event.currentTarget
    const slug = btn.dataset.slug

    if (this.selected.has(slug)) {
      this.selected.delete(slug)
    } else {
      if (this.selected.size >= PALETTE.length) return
      const usedColors = new Set(this.selected.values())
      const color = PALETTE.find(c => !usedColors.has(c)) || PALETTE[0]
      this.selected.set(slug, color)
    }

    this.activePreset = null
    this._syncPresetButtons()
    this._syncModelList()
    this._syncSelCount()
    this._render(true)
  }

  _syncSelCount() {
    if (!this.hasSelCountTarget) return
    const n = this.selected.size
    const span = this.selCountTarget.querySelector(".trends-sel-n")
    if (span) span.textContent = n ? n : "0"
    this.selCountTarget.style.display = n ? "" : "none"
  }

  // ── Toolbar actions ──────────────────────────────────────────────────────────
  setMetric(event) {
    const btn = event.currentTarget
    this.metric = btn.dataset.metric
    btn.closest(".tp-seg").querySelectorAll("button").forEach(b => {
      b.classList.toggle("on", b.dataset.metric === this.metric)
    })
    this._render(true)
  }

  toggleEvents(event) {
    this.showEvents = !this.showEvents
    const btn = event.currentTarget
    btn.classList.toggle("on", this.showEvents)
    btn.setAttribute("aria-checked", this.showEvents ? "true" : "false")
    this._render(false)
    this._renderLegend()
  }

  toggleEventsPopover(event) {
    event.stopPropagation()
    if (!this.hasEventsPopoverTarget) return
    const open = !this.eventsPopoverTarget.classList.contains("open")
    this.eventsPopoverTarget.classList.toggle("open", open)
    if (this.hasEventsPopoverBtnTarget) {
      this.eventsPopoverBtnTarget.setAttribute("aria-expanded", open ? "true" : "false")
    }
  }

  _closePopover() {
    this._closePopover()
    if (this.hasEventsPopoverBtnTarget) {
      this.eventsPopoverBtnTarget.setAttribute("aria-expanded", "false")
    }
  }

  _onOutsideClick(event) {
    if (!this.hasEventsPopoverWrapTarget) return
    if (!this.eventsPopoverWrapTarget.contains(event.target)) {
      this._closePopover()
    }
  }

  // ── Events popover ───────────────────────────────────────────────────────────
  _buildEventsPopover() {
    if (!this.hasEventsPopoverListTarget) return

    this.eventsPopoverListTarget.textContent = ""

    const marketEvents = this.eventsValue
      .filter(e => e.kind === "market")
      .slice()
      .sort((a, b) => a.date.localeCompare(b.date))

    this._marketEvents = marketEvents

    const frag = document.createDocumentFragment()
    marketEvents.forEach((ev, i) => {
      const row = document.createElement("div")
      row.className = "trends-event-row"
      row.dataset.eventDate = ev.date

      const num = document.createElement("span")
      num.className = "trends-event-num"
      num.textContent = i + 1

      const body = document.createElement("span")

      const title = document.createElement("span")
      title.className = "trends-event-title"
      title.textContent = ev.title

      const note = document.createElement("span")
      note.className = "trends-event-note"
      note.textContent = ev.note || ""

      const date = document.createElement("span")
      date.className = "trends-event-date"
      date.textContent = fmtDateFullFromISO(ev.date)

      body.appendChild(title)
      body.appendChild(note)
      body.appendChild(date)

      row.appendChild(num)
      row.appendChild(body)

      row.addEventListener("click", () => {
        this._closePopover()
        if (!this.showEvents) {
          this.showEvents = true
          if (this.hasEventsToggleTarget) {
            this.eventsToggleTarget.classList.add("on")
            this.eventsToggleTarget.setAttribute("aria-checked", "true")
          }
          this._render(false)
          this._renderLegend()
        }
        this._flashEvent(ev.date)
      })

      frag.appendChild(row)
    })

    this.eventsPopoverListTarget.appendChild(frag)
  }

  _flashEvent(dateStr) {
    if (!this.hasSvgTarget) return
    const svg = this.svgTarget

    let idx = -1
    if (this._marketEvents) {
      this._marketEvents.forEach((e, i) => { if (e.date === dateStr) idx = i })
    }
    if (idx < 0) return

    const line = svg.querySelector(`line.tc-event[data-evt="${idx}"]`)
    const mark = svg.querySelector(`.tc-evt-badge[data-evt="${idx}"] .tc-evt-mark`)

    if (line) {
      line.animate(
        [{ strokeWidth: 1.4, opacity: .5 }, { strokeWidth: 4, opacity: 1 }, { strokeWidth: 1.4, opacity: .5 }],
        { duration: 1000, easing: "cubic-bezier(.22,.61,.36,1)", iterations: 2 }
      )
    }
    if (mark) {
      mark.style.transformBox = "fill-box"
      mark.style.transformOrigin = "center"
      mark.animate(
        [{ transform: "scale(1)" }, { transform: "scale(1.7)" }, { transform: "scale(1)" }],
        { duration: 1000, easing: "cubic-bezier(.22,.61,.36,1)", iterations: 2 }
      )
    }
  }

  // ── Chart rendering ──────────────────────────────────────────────────────────
  _render(animate) {
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

    const svg = this.svgTarget
    const W = 880, H = 380, padL = 54, padR = 22, padT = 38, padB = 64
    const iW = W - padL - padR, iH = H - padT - padB

    svg.setAttribute("viewBox", `0 0 ${W} ${H}`)

    const today = new Date()
    today.setUTCHours(0, 0, 0, 0)
    const nowUTC = today.getTime()

    // Build series
    const built = this.modelsValue
      .filter(m => this.selected.has(m.slug))
      .map(m => {
        const color = this.selected.get(m.slug)
        const pts = m.history
          .slice()
          .sort((a, b) => a.date.localeCompare(b.date))
          .map(pp => ({
            t: parseDateUTC(pp.date),
            v: this._metricValue(pp)
          }))
          .filter(p => p.v != null && p.v > 0)
        return { model: m, color, pts }
      })
      .filter(s => s.pts.length)

    if (!built.length) {
      svg.innerHTML = ""
      return
    }

    // Store for hover
    this._built = built
    this._marketEvents = this._marketEvents || this.eventsValue.filter(e => e.kind === "market").sort((a, b) => a.date.localeCompare(b.date))
    const marketEvents = this._marketEvents

    // ── Domains ──
    let tMin = Infinity, tMax = -Infinity, vMax = -Infinity
    built.forEach(s => s.pts.forEach(p => {
      tMin = Math.min(tMin, p.t)
      tMax = Math.max(tMax, p.t)
      vMax = Math.max(vMax, p.v)
    }))
    tMax = Math.max(tMax, nowUTC)
    if (this.showEvents) {
      marketEvents.forEach(e => {
        const t = parseDateUTC(e.date)
        tMin = Math.min(tMin, t)
        tMax = Math.max(tMax, t)
      })
    }
    const tPad = (tMax - tMin) * 0.03
    tMin -= tPad
    tMax += tPad

    // Linear $ axis anchored at 0
    const { top: yTop, ticks: yTicks } = linNice(vMax)

    const x = (t) => padL + ((t - tMin) / (tMax - tMin)) * iW
    const y = (v) => padT + iH - (v / yTop) * iH

    // Store geometry for hover
    this._geom = { x, y, padL, padT, iW, iH, nowUTC, built, tMin, tMax, W, H, yTop }

    let g = ""

    // ── Y gridlines + labels ──
    yTicks.forEach(tk => {
      const gy = y(tk)
      g += `<line class="tc-grid" x1="${padL}" y1="${gy.toFixed(1)}" x2="${W - padR}" y2="${gy.toFixed(1)}"/>`
      g += `<text class="tc-axis" x="${(padL - 9)}" y="${(gy + 3.5).toFixed(1)}" text-anchor="end">$${fmtMoney(tk)}</text>`
    })

    // ── X axis month ticks ──
    monthTicks(tMin, tMax).forEach(t => {
      const gx = x(t)
      g += `<line class="tc-grid tc-grid-v" x1="${gx.toFixed(1)}" y1="${padT}" x2="${gx.toFixed(1)}" y2="${padT + iH}"/>`
      g += `<text class="tc-axis" x="${gx.toFixed(1)}" y="${padT + iH + 20}" text-anchor="middle">${fmtAxisDate(t)}</text>`
    })

    // ── Event dashed guide lines ──
    if (this.showEvents) {
      marketEvents.forEach((e, i) => {
        const ex = x(parseDateUTC(e.date))
        g += `<line class="tc-event" x1="${ex.toFixed(1)}" y1="${padT - 10}" x2="${ex.toFixed(1)}" y2="${padT + iH}" data-evt="${i}"/>`
      })
    }

    // ── Lines (stepwise) ──
    built.forEach(s => {
      const segs = []
      s.pts.forEach((p, i) => {
        const px = x(p.t), py = y(p.v)
        if (i === 0) {
          segs.push("M" + px.toFixed(1) + " " + py.toFixed(1))
        } else {
          const prevY = y(s.pts[i - 1].v)
          segs.push("L" + px.toFixed(1) + " " + prevY.toFixed(1))
          segs.push("L" + px.toFixed(1) + " " + py.toFixed(1))
        }
      })
      const last = s.pts[s.pts.length - 1]
      segs.push("L" + x(nowUTC).toFixed(1) + " " + y(last.v).toFixed(1))

      g += `<path class="tc-line" d="${segs.join(" ")}" stroke="${s.color}" data-slug="${s.model.slug}"/>`

      s.pts.forEach(p => {
        g += `<circle class="tc-pt" cx="${x(p.t).toFixed(1)}" cy="${y(p.v).toFixed(1)}" r="3.2" fill="#fff" stroke="${s.color}" data-slug="${s.model.slug}"/>`
      })

      g += `<circle class="tc-pt tc-pt-end" cx="${x(nowUTC).toFixed(1)}" cy="${y(last.v).toFixed(1)}" r="4" fill="${s.color}" data-slug="${s.model.slug}"/>`
    })

    // Crosshair + focus dot (hidden initially)
    g += `<line class="tc-cross" x1="0" y1="${padT}" x2="0" y2="${padT + iH}" style="opacity:0"/>`
    g += `<circle class="tc-hoverdot" r="5.5" style="opacity:0"/>`

    svg.innerHTML = g

    // ── Mouse-capture overlay (under event markers) ──
    const overlay = document.createElementNS(SVG_NS, "rect")
    overlay.setAttribute("class", "tc-overlay")
    overlay.setAttribute("x", padL)
    overlay.setAttribute("y", padT)
    overlay.setAttribute("width", iW)
    overlay.setAttribute("height", iH)
    overlay.setAttribute("fill", "transparent")
    overlay.style.cursor = "crosshair"
    svg.appendChild(overlay)

    // ── Event marker badges (numbered, on top) ──
    if (this.showEvents) {
      let layer = ""
      marketEvents.forEach((e, i) => {
        const ex = x(parseDateUTC(e.date))
        layer += `<g class="tc-evt-badge" data-evt="${i}">` +
          `<circle class="tc-evt-hit" cx="${ex.toFixed(1)}" cy="16" r="17" fill="transparent"/>` +
          `<circle class="tc-evt-mark" cx="${ex.toFixed(1)}" cy="16" r="10"/>` +
          `<text class="tc-evt-num" x="${ex.toFixed(1)}" y="16.5" text-anchor="middle" dominant-baseline="central">${i + 1}</text>` +
          `</g>`
      })
      svg.insertAdjacentHTML("beforeend", layer)
    }

    // ── Animation ──
    const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches
    if (animate && !reduce) {
      svg.querySelectorAll(".tc-line").forEach((ln, i) => {
        const len = ln.getTotalLength()
        ln.style.strokeDasharray = len
        ln.style.strokeDashoffset = len
        ln.animate(
          [{ strokeDashoffset: len }, { strokeDashoffset: 0 }],
          { duration: 900, delay: i * 55, easing: "cubic-bezier(.22,.61,.36,1)", fill: "forwards" }
        )
      })
      svg.querySelectorAll(".tc-pt, .tc-event, .tc-evt-badge").forEach(el => {
        el.animate([{ opacity: 0 }, { opacity: 1 }], { duration: 400, delay: 520, fill: "backwards" })
      })
    }

    this._bindHover()
    this._renderLegend()
  }

  _metricValue(pp) {
    if (this.metric === "input") return pp.input
    if (this.metric === "output") return pp.output
    if (pp.input == null || pp.output == null) return null
    return (3 * pp.input + pp.output) / 4
  }

  // ── Line emphasis (dim/focus) ────────────────────────────────────────────────
  _emphasize(slug) {
    if (!this.hasSvgTarget) return
    this.svgTarget.querySelectorAll(".tc-line, .tc-pt").forEach(el => {
      const on = !slug || el.dataset.slug === slug
      el.classList.toggle("tc-dim", !on)
      el.classList.toggle("tc-focus", !!slug && on && el.classList.contains("tc-line"))
    })
  }

  // ── Hover binding ────────────────────────────────────────────────────────────
  _bindHover() {
    const svg = this.svgTarget
    const gm = this._geom
    const tip = this.hasTooltipTarget ? this.tooltipTarget : null
    const etip = this.hasEventTooltipTarget ? this.eventTooltipTarget : null
    const built = gm.built
    const metricLabel = METRIC_LABEL[this.metric] || ""
    const marketEvents = this._marketEvents || []

    // ── Event marker hover ──
    if (etip) {
      svg.querySelectorAll(".tc-evt-badge").forEach(badge => {
        const e = marketEvents[+badge.dataset.evt]
        if (!e) return

        const show = () => {
          etip.innerHTML =
            `<div class="et-kind et-market">Market event · #${+badge.dataset.evt + 1}</div>` +
            `<div class="et-title">${esc(e.title)}</div>` +
            `<div class="et-date">${fmtDateFullFromISO(e.date)}</div>` +
            `<div class="et-note">${esc(e.note || "")}</div>`
          const r = svg.getBoundingClientRect()
          const cx = (+badge.querySelector(".tc-evt-mark").getAttribute("cx") / gm.W) * r.width
          etip.style.left = cx + "px"
          etip.style.opacity = 1
          etip.classList.toggle("flip", cx > r.width * 0.58)
          badge.classList.add("on")
        }
        const hide = () => {
          etip.style.opacity = 0
          badge.classList.remove("on")
        }
        badge.addEventListener("mouseenter", show)
        badge.addEventListener("mouseleave", hide)
      })
    }

    if (!tip) return
    const overlay = svg.querySelector(".tc-overlay")
    if (!overlay) return

    const cross = svg.querySelector(".tc-cross")
    const hoverdot = svg.querySelector(".tc-hoverdot")

    const valAt = (s, t) => {
      let v = s.pts[0].v
      for (const p of s.pts) { if (p.t <= t) v = p.v }
      return v
    }

    overlay.addEventListener("mousemove", (ev) => {
      const r = svg.getBoundingClientRect()
      const sx = gm.W / r.width, sy = gm.H / r.height
      const px = (ev.clientX - r.left) * sx
      const py = (ev.clientY - r.top) * sy
      const t = gm.tMin + ((px - gm.padL) / gm.iW) * (gm.tMax - gm.tMin)

      // Nearest line by vertical distance at cursor x
      let best = null, bestD = Infinity
      built.forEach(s => {
        const ly = gm.y(valAt(s, t))
        const d = Math.abs(ly - py)
        if (d < bestD) { bestD = d; best = s }
      })
      if (!best) return

      this._emphasize(best.model.slug)

      const v = valAt(best, t)
      const ly = gm.y(v)
      cross.setAttribute("x1", px)
      cross.setAttribute("x2", px)
      cross.style.opacity = 1
      hoverdot.setAttribute("cx", px)
      hoverdot.setAttribute("cy", ly)
      hoverdot.setAttribute("fill", best.color)
      hoverdot.style.opacity = 1

      tip.innerHTML =
        `<div class="ttc-name"><span class="ttc-dot" style="background:${best.color}"></span>${esc(best.model.name)}</div>` +
        `<div class="ttc-price num">$${this._fmtTipPrice(v)}<small> /1M ${esc(metricLabel)}</small></div>` +
        `<div class="ttc-date">as of ${fmtAxisDate(t)}</div>`
      const tx = (px / gm.W) * r.width
      tip.style.left = tx + "px"
      tip.style.opacity = 1
      tip.classList.toggle("flip", tx > r.width * 0.6)
    })

    overlay.addEventListener("mouseleave", () => {
      cross.style.opacity = 0
      hoverdot.style.opacity = 0
      tip.style.opacity = 0
      this._emphasize(null)
    })
  }

  _fmtTipPrice(v) {
    if (v == null) return "—"
    if (v === 0) return "0"
    if (v < 1) return parseFloat(v.toFixed(4)).toString()
    if (v < 10) return v.toFixed(2).replace(/\.?0+$/, "")
    return v.toFixed(2).replace(/\.?0+$/, "")
  }

  // ── Legend ───────────────────────────────────────────────────────────────────
  _renderLegend() {
    if (!this.hasLegendTarget) return
    const legend = this.legendTarget
    legend.innerHTML = ""

    const built = this._built || []
    built.forEach(({ model: m, color }) => {
      const item = document.createElement("span")
      item.className = "trends-legend-item"
      item.dataset.slug = m.slug

      const line = document.createElement("span")
      line.className = "trends-legend-line"
      line.style.background = color
      item.appendChild(line)
      item.appendChild(document.createTextNode(m.name))

      item.addEventListener("mouseover", () => this._emphasize(m.slug))
      item.addEventListener("mouseout", () => this._emphasize(null))

      legend.appendChild(item)
    })

    if (this.showEvents) {
      const evtItem = document.createElement("span")
      evtItem.className = "trends-legend-evt"
      const dash = document.createElement("span")
      dash.className = "trends-legend-dash"
      evtItem.appendChild(dash)
      evtItem.appendChild(document.createTextNode("Numbered markers = market events"))
      legend.appendChild(evtItem)
    }
  }
}
