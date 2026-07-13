import { Controller } from "@hotwired/stimulus"

// Hover/focus-triggered native popover for the model-name cell in the price
// table. Content is already server-rendered inline (the row is Russian-doll
// cached and the model is already loaded — no per-hover fetch needed, unlike
// a click-triggered popovertarget panel). A short close delay avoids flicker
// when the pointer crosses the gap between the trigger and the card; entering
// the card itself cancels the pending hide since it's a DOM descendant of
// this controller's element (top-layer rendering only changes paint order,
// not event bubbling).
export default class extends Controller {
  static targets = ["card"]

  show() {
    clearTimeout(this.hideTimeout)
    if (this.hasCardTarget && !this.cardTarget.matches(":popover-open")) {
      this.cardTarget.showPopover()
    }
  }

  hide() {
    if (!this.hasCardTarget) return
    this.hideTimeout = setTimeout(() => {
      if (this.cardTarget.matches(":popover-open")) this.cardTarget.hidePopover()
    }, 150)
  }

  position(event) {
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
  }
}
