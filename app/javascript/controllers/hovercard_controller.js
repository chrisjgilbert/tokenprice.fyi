import { Controller } from "@hotwired/stimulus"

// Hover/focus-triggered native popover for the model-name cell in the price
// table. Content is already server-rendered inline (the row is Russian-doll
// cached and the model is already loaded — no per-hover fetch needed, unlike
// a click-triggered popovertarget panel). A short close delay avoids flicker
// when the pointer crosses the gap between the trigger and the card; entering
// the card itself cancels the pending hide since it's a DOM descendant of
// this controller's element (top-layer rendering only changes paint order,
// not event bubbling).
//
// popover="manual" (not the bare, auto-type "popover" the facet filter panels
// use) deliberately opts out of the platform's auto-popover-group behavior:
// an auto popover closes every other open auto popover on the page, so
// hovering a row while a facet dropdown is open would silently close the
// dropdown. That also means the platform no longer enforces "only one open
// at a time" for us — one card is taller than a table row, so an open card
// can visually cover the row(s) beneath it. `openHovercard` below restores
// single-card-at-a-time ourselves, scoped to just this controller's own
// popovers (never touching the facet panel's).
let openHovercard = null

export default class extends Controller {
  static targets = ["card"]

  connect() {
    this.onScroll = () => this.closeNow()
    // Capture phase: catches scroll on any scrollable ancestor (e.g. the
    // table's horizontal scroll wrapper), not just window-level scroll.
    window.addEventListener("scroll", this.onScroll, { capture: true, passive: true })

    // Document-level, not scoped to this row: a mouse-hovered (not focused)
    // card has no element inside the row to bubble a keydown through, so a
    // per-row Escape action would only work for the keyboard/focus path.
    this.onKeydown = (event) => {
      if (event.key === "Escape") this.closeNow()
    }
    document.addEventListener("keydown", this.onKeydown)
  }

  show() {
    clearTimeout(this.hideTimeout)
    if (!this.hasCardTarget || this.cardTarget.matches(":popover-open")) return
    if (openHovercard && openHovercard !== this) openHovercard.closeNow()
    openHovercard = this
    this.cardTarget.showPopover()
  }

  hide() {
    if (!this.hasCardTarget) return
    clearTimeout(this.hideTimeout)
    this.hideTimeout = setTimeout(() => this.closeNow(), 150)
  }

  closeNow() {
    clearTimeout(this.hideTimeout)
    if (this.hasCardTarget && this.cardTarget.matches(":popover-open")) this.cardTarget.hidePopover()
    if (openHovercard === this) openHovercard = null
  }

  // Swallows clicks landing on the card's own content (a price tag, the tier
  // badge, ...) so they don't bubble to the row's click->compare-tray#rowClick
  // and trigger a navigation or compare-toggle the user didn't intend.
  swallow() {}

  position(event) {
    this.element.setAttribute("aria-expanded", event.newState === "open" ? "true" : "false")
    if (event.newState !== "open") return

    const margin = 8
    const gap = 6
    const anchor = this.element.getBoundingClientRect()
    const card = this.cardTarget.getBoundingClientRect()

    const left = Math.max(margin, Math.min(anchor.left, window.innerWidth - card.width - margin))
    const fitsBelow = anchor.bottom + gap + card.height <= window.innerHeight - margin
    const top = fitsBelow ? anchor.bottom + gap : Math.max(margin, anchor.top - gap - card.height)

    this.cardTarget.style.left = `${left}px`
    this.cardTarget.style.top = `${top}px`
  }

  disconnect() {
    clearTimeout(this.hideTimeout)
    if (openHovercard === this) openHovercard = null
    window.removeEventListener("scroll", this.onScroll, { capture: true })
    document.removeEventListener("keydown", this.onKeydown)
  }
}
