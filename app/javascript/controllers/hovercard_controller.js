import { Controller } from "@hotwired/stimulus"
import { clampToViewport } from "clamp_to_viewport"

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
// dropdown. popover="hint" is the closer platform match (it doesn't close
// other auto popovers, but still gets Escape/light-dismiss/one-at-a-time for
// free) — not used yet because Safari hasn't shipped it, and an unsupported
// value silently reflects to "auto", quietly reintroducing the dropdown bug
// for Safari only. Revisit once hint reaches Baseline.
//
// `openHovercard` and the two listeners below are module-level, not
// per-instance: at most one hovercard can ever be open (that's the whole
// point of `openHovercard`), so one shared listener pair closing whichever
// instance is currently open does the same job as attaching a copy to every
// row without the O(rows) listener churn on every connect/disconnect.
let openHovercard = null

window.addEventListener("scroll", () => openHovercard?.closeNow(), { capture: true, passive: true })
document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") openHovercard?.closeNow()
})

export default class extends Controller {
  static targets = ["card"]

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

    const { left, top } = clampToViewport(this.element.getBoundingClientRect(), this.cardTarget.getBoundingClientRect())
    this.cardTarget.style.left = `${left}px`
    this.cardTarget.style.top = `${top}px`
  }

  disconnect() {
    clearTimeout(this.hideTimeout)
    if (openHovercard === this) openHovercard = null
  }
}
