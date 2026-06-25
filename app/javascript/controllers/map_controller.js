import { Controller } from "@hotwired/stimulus"

// Progressive enhancement for the world map: the country shapes are already
// real links into the filtered price table (they work without JS). This adds a
// rich hover/focus card showing each country's provider/model counts, average
// price and cheapest model, tracking the pointer across the map.
export default class extends Controller {
  static targets = ["tooltip"]
  static values = { countries: Object }

  show(event) {
    const link = event.target.closest("[data-code]")
    if (!link) return this.hide()

    const c = this.countriesValue[link.dataset.code]
    if (!c) return this.hide()

    this.tooltipTarget.innerHTML = this.card(c)
    this.tooltipTarget.classList.add("visible")
    this.position(event, link)
  }

  move(event) {
    if (this.tooltipTarget.classList.contains("visible")) this.position(event)
  }

  hide() {
    this.tooltipTarget.classList.remove("visible")
  }

  // Anchor the card to the pointer; on keyboard focus (no pointer coords) fall
  // back to the focused country's own centre so it doesn't jump to the middle
  // of the map. Clamp so it never spills out of the map card.
  position(event, link = null) {
    const card = this.element.getBoundingClientRect()
    const tip = this.tooltipTarget
    const pad = 14

    let anchorX = event.clientX
    let anchorY = event.clientY
    if (anchorX == null) {
      const box = (link || event.target.closest("[data-code]") || event.target).getBoundingClientRect()
      anchorX = box.left + box.width / 2
      anchorY = box.top + box.height / 2
    }

    const x = anchorX - card.left
    const y = anchorY - card.top

    let left = x + pad
    if (left + tip.offsetWidth > card.width) left = x - tip.offsetWidth - pad
    left = Math.max(4, Math.min(left, card.width - tip.offsetWidth - 4))

    let top = y + pad
    top = Math.max(4, Math.min(top, card.height - tip.offsetHeight - 4))

    tip.style.left = `${left}px`
    tip.style.top = `${top}px`
  }

  card(c) {
    // Counts are server-provided integers; coerce defensively so they can never
    // smuggle markup into innerHTML even if the payload shape ever changes.
    const providers = Number(c.providers)
    const models = Number(c.models)
    const frontier = Number(c.frontier)

    const cheapest = c.cheapest
      ? `<div class="map-tip-k">Cheapest</div><div class="map-tip-v">${this.esc(c.cheapest.io)}</div>`
      : ""

    return `
      <div class="map-tip-head">
        <span class="map-tip-flag">${this.esc(c.flag || "")}</span>
        <div>
          <div class="map-tip-name">${this.esc(c.name)}</div>
          <div class="map-tip-sub">${providers} provider${providers === 1 ? "" : "s"} · ${models} model${models === 1 ? "" : "s"}</div>
        </div>
      </div>
      <div class="map-tip-rows">
        <div class="map-tip-k">Frontier</div><div class="map-tip-v">${frontier}</div>
        <div class="map-tip-k">Median input /1M</div><div class="map-tip-v">${this.esc(c.median)}</div>
        ${cheapest}
      </div>
      <div class="map-tip-cta">Click to filter the price table →</div>
    `
  }

  esc(value) {
    const el = document.createElement("div")
    el.textContent = value ?? ""
    return el.innerHTML
  }
}
