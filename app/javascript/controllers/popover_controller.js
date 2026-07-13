import { Controller } from "@hotwired/stimulus"
import { clampToViewport } from "clamp_to_viewport"

// Positions a native popover under the button that opened it, clamped to the
// viewport and flipped above when there's no room below. The Popover API itself
// handles opening, light-dismiss, focus and top-layer rendering (so the filters
// card's overflow can't clip it); this only places it. CSS anchor positioning
// would do the placement declaratively, but isn't broadly supported across
// browsers yet, so we do it here. No page-level state, so a Turbo navigation
// that re-renders the markup just gets a fresh controller.
export default class extends Controller {
  position(event) {
    const invoker = document.querySelector(`[popovertarget="${this.element.id}"]`)
    if (!invoker) return

    // The Popover API has no built-in ARIA wiring (unlike <details>/<summary>,
    // which this replaced for the provider facet); mirror the open/closed
    // state onto the trigger ourselves so it's announced.
    invoker.setAttribute("aria-expanded", event.newState === "open" ? "true" : "false")
    if (event.newState !== "open") return

    const { left, top } = clampToViewport(invoker.getBoundingClientRect(), this.element.getBoundingClientRect())
    this.element.style.left = `${left}px`
    this.element.style.top = `${top}px`
  }
}
