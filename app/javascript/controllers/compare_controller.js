import { Controller } from "@hotwired/stimulus"

// Manages the model-selector popovers, search filtering, swap button,
// and URL sync for the Compare page.
export default class extends Controller {
  static targets = [
    "popA", "popB",       // popover panels
    "btnA", "btnB",       // selector trigger buttons
    "searchA", "searchB", // search inputs inside popovers
    "listA", "listB",     // <ul> model lists
    "swapBtn"
  ]

  static values = {
    slugA: String,
    slugB: String
  }

  connect() {
    this._boundOutside = this._onOutsideClick.bind(this)
    this._boundEsc     = this._onEsc.bind(this)
    document.addEventListener("click", this._boundOutside, true)
    document.addEventListener("keydown", this._boundEsc)
  }

  disconnect() {
    document.removeEventListener("click", this._boundOutside, true)
    document.removeEventListener("keydown", this._boundEsc)
  }

  // ── Open / close ────────────────────────────────────────────────────────────

  toggleA(event) {
    event.stopPropagation()
    this._toggle("A")
  }

  toggleB(event) {
    event.stopPropagation()
    this._toggle("B")
  }

  _toggle(side) {
    const isOpen = this[`pop${side}Target`].classList.contains("open")
    this._closeAll()
    if (!isOpen) this._open(side)
  }

  _open(side) {
    const pop    = this[`pop${side}Target`]
    const btn    = this[`btn${side}Target`]
    const search = this[`search${side}Target`]
    pop.classList.add("open")
    btn.setAttribute("aria-expanded", "true")
    search.value = ""
    this._filterList(side, "")
    requestAnimationFrame(() => search.focus())
  }

  _closeAll() {
    ;["A", "B"].forEach((side) => {
      const pop = this[`pop${side}Target`]
      const btn = this[`btn${side}Target`]
      pop.classList.remove("open")
      btn.setAttribute("aria-expanded", "false")
    })
  }

  _onOutsideClick(event) {
    const inside = this.element.contains(event.target)
    if (!inside) this._closeAll()
  }

  _onEsc(event) {
    if (event.key === "Escape") this._closeAll()
  }

  // ── Search filtering ────────────────────────────────────────────────────────

  searchA(event) {
    this._filterList("A", event.target.value)
  }

  searchB(event) {
    this._filterList("B", event.target.value)
  }

  _filterList(side, query) {
    const list  = this[`list${side}Target`]
    const items = list.querySelectorAll("[data-model-name]")
    const q     = query.toLowerCase().trim()

    items.forEach((item) => {
      if (!q) {
        item.hidden = false
        return
      }
      const name     = (item.dataset.modelName     || "").toLowerCase()
      const provider = (item.dataset.modelProvider || "").toLowerCase()
      item.hidden = !name.includes(q) && !provider.includes(q)
    })
  }

  // ── Selection ───────────────────────────────────────────────────────────────

  // Called by data-action on each list item button; data-side and data-slug attrs
  pick(event) {
    const btn  = event.currentTarget
    const side = btn.dataset.side
    const slug = btn.dataset.slug

    if (btn.disabled || btn.getAttribute("aria-disabled") === "true") return

    if (side === "A") {
      this.slugAValue = slug
    } else {
      this.slugBValue = slug
    }

    this._closeAll()
    this._navigate()
  }

  // ── Swap ────────────────────────────────────────────────────────────────────

  swap(event) {
    event.preventDefault()
    const tmp        = this.slugAValue
    this.slugAValue  = this.slugBValue
    this.slugBValue  = tmp
    this._navigate()
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  _navigate() {
    const url = new URL(window.location.href)
    url.searchParams.set("a", this.slugAValue)
    url.searchParams.set("b", this.slugBValue)
    // Turbo.visit does a full page replace which re-renders the server HTML
    // and updates the browser URL — exactly what we need.
    window.Turbo?.visit(url.toString(), { action: "replace" })
  }
}
