import { Controller } from "@hotwired/stimulus"

// Positions a native popover under the button that opened it, clamped to the
// viewport and flipped above when there's no room below. The Popover API itself
// handles opening, light-dismiss, focus and top-layer rendering (so the filters
// card's overflow can't clip it); this only places it. CSS anchor positioning
// would do the placement declaratively, but isn't broadly supported across
// browsers yet, so we do it here. No page-level state, so a Turbo navigation
// that re-renders the markup just gets a fresh controller.
export default class extends Controller {
  position(event) {
    if (event.newState !== "open") return

    const invoker = document.querySelector(`[popovertarget="${this.element.id}"]`)
    if (!invoker) return

    const margin = 8
    const gap = 6
    const anchor = invoker.getBoundingClientRect()
    const self = this.element.getBoundingClientRect()

    const left = Math.max(margin, Math.min(anchor.left, window.innerWidth - self.width - margin))
    const fitsBelow = anchor.bottom + gap + self.height <= window.innerHeight - margin
    const top = fitsBelow ? anchor.bottom + gap : Math.max(margin, anchor.top - gap - self.height)

    this.element.style.left = `${left}px`
    this.element.style.top = `${top}px`
  }

  // Dismiss after a single-select pick (the tier/modality facet dropdowns).
  // A no-op on desktop, where the panel lays out inline and is never an open
  // popover — hidePopover() would otherwise throw on a panel that isn't open.
  close() {
    if (this.element.matches(":popover-open")) this.element.hidePopover()
  }
}
