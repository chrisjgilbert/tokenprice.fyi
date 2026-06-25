import { Controller } from "@hotwired/stimulus"

// Progressively enhances the server-rendered price-history SVG (ChartsHelper#
// price_history_chart) with hover interactivity: a vertical crosshair, a marker
// on each series, and a floating tooltip that snaps to the nearest price point.
//
// The chart is fully functional without this controller — every value is in the
// static SVG and the Snapshots table below it. This only adds pointer affordances.
export default class extends Controller {
  static targets = ["svg", "overlay", "crosshair", "inputDot", "outputDot", "tooltip"]
  static values = { points: Array, geometry: Object }

  connect() {
    // A single point has nothing to scrub between; leave it as a static marker.
    if (this.pointsValue.length < 2) this.overlayTarget.style.pointerEvents = "none"
  }

  move(event) {
    const point = this.nearest(this.svgX(event.clientX))
    if (!point) return

    this.crosshairTarget.setAttribute("x1", point.x)
    this.crosshairTarget.setAttribute("x2", point.x)
    this.placeDot(this.inputDotTarget, point.x, point.input.y)
    this.placeDot(this.outputDotTarget, point.x, point.output.y)
    this.crosshairTarget.setAttribute("visibility", "visible")

    this.renderTooltip(point)
  }

  leave() {
    this.crosshairTarget.setAttribute("visibility", "hidden")
    this.inputDotTarget.setAttribute("visibility", "hidden")
    this.outputDotTarget.setAttribute("visibility", "hidden")
    this.tooltipTarget.classList.add("hidden")
  }

  placeDot(dot, x, y) {
    dot.setAttribute("cx", x)
    dot.setAttribute("cy", y)
    dot.setAttribute("visibility", "visible")
  }

  // Client X (pixels) → SVG user-space X, accounting for the chart's responsive scaling.
  svgX(clientX) {
    const rect = this.svgTarget.getBoundingClientRect()
    return ((clientX - rect.left) / rect.width) * this.geometryValue.width
  }

  nearest(x) {
    return this.pointsValue.reduce((best, p) =>
      best === null || Math.abs(p.x - x) < Math.abs(best.x - x) ? p : best, null)
  }

  renderTooltip(point) {
    const tip = this.tooltipTarget
    tip.innerHTML =
      `<div class="mb-1 font-medium text-slate-300">${point.date}</div>` +
      this.row("#818cf8", "Input", point.input.label) +
      this.row("#fb7185", "Output", point.output.label)
    tip.classList.remove("hidden")

    // Position above the higher of the two markers, centred on the crosshair,
    // clamped to the chart so it never spills past an edge.
    const rect = this.svgTarget.getBoundingClientRect()
    const scaleX = rect.width / this.geometryValue.width
    const scaleY = rect.height / this.geometryValue.height
    const half = tip.offsetWidth / 2
    const left = Math.max(half, Math.min(rect.width - half, point.x * scaleX))
    const top = Math.min(point.input.y, point.output.y) * scaleY

    tip.style.left = `${left}px`
    tip.style.top = `${top}px`
    tip.style.transform = "translate(-50%, calc(-100% - 12px))"
  }

  row(color, name, value) {
    return `<div class="flex items-center justify-between gap-4 tabular-nums">` +
      `<span class="flex items-center gap-1.5 text-slate-200"><span class="inline-block h-2 w-2 rounded-full" style="background:${color}"></span>${name}</span>` +
      `<span class="font-semibold text-white">${value}</span></div>`
  }
}
