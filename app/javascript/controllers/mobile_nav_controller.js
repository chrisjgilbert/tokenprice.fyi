import { Controller } from "@hotwired/stimulus"

// Slide-down mobile menu. Lives on the <nav>; the toggle button opens a panel
// anchored under the bar. Closes on the scrim, Escape, navigation (Turbo
// visit), or a resize back up to the desktop layout. While open it locks body
// scroll, marks the rest of the page inert, and traps Tab focus inside the
// panel so keyboard and screen-reader users stay within the menu.
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
    if (this.element.classList.contains("menu-open")) return
    this.element.classList.add("menu-open")
    this.toggleTarget.setAttribute("aria-expanded", "true")
    document.body.style.overflow = "hidden"
    this.setBackgroundInert(true)
    document.addEventListener("keydown", this.onKeydown)
    document.addEventListener("turbo:before-visit", this.close)
    window.addEventListener("resize", this.closeIfWide)
    this.focusables()[0]?.focus()
  }

  close = () => {
    const hadFocusInPanel = this.hasPanelTarget && this.panelTarget.contains(document.activeElement)
    this.element.classList.remove("menu-open")
    if (this.hasToggleTarget) this.toggleTarget.setAttribute("aria-expanded", "false")
    document.body.style.overflow = ""
    this.setBackgroundInert(false)
    document.removeEventListener("keydown", this.onKeydown)
    document.removeEventListener("turbo:before-visit", this.close)
    window.removeEventListener("resize", this.closeIfWide)
    // Pull focus back to the toggle if it was stranded inside the closing panel.
    if (hadFocusInPanel && this.hasToggleTarget) this.toggleTarget.focus()
  }

  onKeydown = (event) => {
    if (event.key === "Escape") return this.close()
    if (event.key === "Tab") this.trapTab(event)
  }

  // Keep Tab within the panel: wrap from last back to first and vice versa.
  trapTab(event) {
    const items = this.focusables()
    if (items.length === 0) return
    const first = items[0]
    const last = items[items.length - 1]
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus()
    }
  }

  focusables() {
    if (!this.hasPanelTarget) return []
    return Array.from(this.panelTarget.querySelectorAll("a[href], button:not([disabled])"))
  }

  // Hide the page behind the drawer from tab order and assistive tech.
  setBackgroundInert(on) {
    document.querySelectorAll("main, footer").forEach((el) => {
      on ? el.setAttribute("inert", "") : el.removeAttribute("inert")
    })
  }

  // The desktop nav reappears above 760px; drop the panel so it can't linger.
  closeIfWide = () => {
    if (window.innerWidth > 760) this.close()
  }

  disconnect() {
    this.close()
  }
}
