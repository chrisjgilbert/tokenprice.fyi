import { Controller } from "@hotwired/stimulus"

// Filters the market-events timeline by kind (all / market / launch). Entries are
// hidden with the [hidden] attribute so they leave both the layout and the
// accessibility tree; a year header with nothing left to show is hidden too.
export default class extends Controller {
  static targets = ["tab", "item", "yearGroup", "status", "empty"]

  select(event) {
    this.apply(event.currentTarget.dataset.kind)
  }

  apply(kind) {
    let shown = 0
    this.itemTargets.forEach((item) => {
      const match = kind === "all" || item.dataset.kind === kind
      item.hidden = !match
      if (match) shown++
    })

    this.yearGroupTargets.forEach((group) => {
      const visible = this.itemTargets.some((item) => !item.hidden && group.contains(item))
      group.hidden = !visible
    })

    this.tabTargets.forEach((tab) => {
      const on = tab.dataset.kind === kind
      tab.classList.toggle("on", on)
      tab.setAttribute("aria-pressed", on ? "true" : "false")
    })

    if (this.hasEmptyTarget) this.emptyTarget.hidden = shown > 0
    this.announce(kind, shown)
  }

  announce(kind, shown) {
    if (!this.hasStatusTarget) return
    if (kind === "all") {
      this.statusTarget.textContent = ""
      return
    }
    const label = kind === "market" ? "market events" : "launches"
    this.statusTarget.textContent = `Showing ${shown} ${label}.`
  }
}
