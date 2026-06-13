import { Controller } from "@hotwired/stimulus"

// A small click-to-toggle disclosure (used by the nav "Learn" group). Opens on
// the trigger, closes on outside click, Escape, or selecting an item. Keeps
// aria-expanded in sync for assistive tech. On the mobile scroll-nav the menu is
// flattened to inline links via CSS, so this controller is a no-op there.
export default class extends Controller {
  static targets = ["menu", "trigger"]

  // Turbo can restore a cached snapshot with the menu left open; start closed.
  connect() {
    this.element.classList.remove("open")
    this.triggerTarget.setAttribute("aria-expanded", "false")
  }

  toggle(event) {
    event.preventDefault()
    this.element.classList.contains("open") ? this.hide() : this.show()
  }

  show() {
    this.element.classList.add("open")
    this.triggerTarget.setAttribute("aria-expanded", "true")
    document.addEventListener("click", this.hideOnOutside)
    document.addEventListener("keydown", this.hideOnEscape)
  }

  hide() {
    this.element.classList.remove("open")
    this.triggerTarget.setAttribute("aria-expanded", "false")
    document.removeEventListener("click", this.hideOnOutside)
    document.removeEventListener("keydown", this.hideOnEscape)
  }

  hideOnOutside = (event) => {
    if (!this.element.contains(event.target)) this.hide()
  }

  hideOnEscape = (event) => {
    if (event.key === "Escape") {
      this.hide()
      this.triggerTarget.focus()
    }
  }

  disconnect() {
    document.removeEventListener("click", this.hideOnOutside)
    document.removeEventListener("keydown", this.hideOnEscape)
  }
}
