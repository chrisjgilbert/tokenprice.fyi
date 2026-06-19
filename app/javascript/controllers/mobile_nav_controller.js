import { Controller } from "@hotwired/stimulus"

// Slide-down mobile menu. Lives on the <nav>; the toggle button opens a panel
// anchored under the bar. Closes on the scrim, Escape, navigation (Turbo
// visit), or a resize back up to the desktop layout. Locks body scroll while
// open and keeps aria-expanded in sync.
export default class extends Controller {
  static targets = ["panel", "toggle"]

  // Turbo can restore a cached snapshot with the menu left open; start closed.
  connect() {
    this.close()
  }

  toggle(event) {
    event.preventDefault()
    this.element.classList.contains("menu-open") ? this.close() : this.open()
  }

  open() {
    this.element.classList.add("menu-open")
    this.toggleTarget.setAttribute("aria-expanded", "true")
    document.body.style.overflow = "hidden"
    document.addEventListener("keydown", this.closeOnEscape)
    document.addEventListener("turbo:before-visit", this.close)
    window.addEventListener("resize", this.closeIfWide)
  }

  close = () => {
    this.element.classList.remove("menu-open")
    if (this.hasToggleTarget) this.toggleTarget.setAttribute("aria-expanded", "false")
    document.body.style.overflow = ""
    document.removeEventListener("keydown", this.closeOnEscape)
    document.removeEventListener("turbo:before-visit", this.close)
    window.removeEventListener("resize", this.closeIfWide)
  }

  closeOnEscape = (event) => {
    if (event.key === "Escape") {
      this.close()
      this.toggleTarget.focus()
    }
  }

  // The desktop nav reappears above 760px; drop the panel so it can't linger.
  closeIfWide = () => {
    if (window.innerWidth > 760) this.close()
  }

  disconnect() {
    this.close()
  }
}
