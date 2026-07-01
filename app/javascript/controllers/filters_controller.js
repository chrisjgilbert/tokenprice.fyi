import { Controller } from "@hotwired/stimulus"

// Submits the filter form: immediately when a pill is toggled, debounced
// while typing in the search box. Also keeps the form in sync with the URL
// on history navigation, and announces result counts to screen readers.
export default class extends Controller {
  static targets = ["status"]
  static values = { delay: { type: Number, default: 300 } }

  // Turbo restoration visits (Back/Forward) render cached snapshots that
  // don't capture typed input state, so the form can lag the URL/table.
  // Re-seed it from the query string whenever the controller (re)connects.
  // Every facet is a multi-select checkbox group now, so a box is checked iff
  // its value is present under its field name (tier[], providers[], modality[]).
  connect() {
    const params = new URLSearchParams(window.location.search)

    this.element.querySelectorAll("input").forEach((input) => {
      if (input.type === "checkbox") {
        input.checked = params.getAll(input.name).includes(input.value)
      } else if (input.type === "search" || input.type === "text") {
        input.value = params.get(input.name) || ""
      }
    })

    this.syncChips()
  }

  // Keep the facet dropdown chips in step with the checkboxes inside their
  // panels: the chips live outside the Turbo frame, so nothing else refreshes
  // them. No boxes checked means "all" (the form omits an empty filter), so a
  // chip's count badge shows only when the selection is a proper, non-empty
  // subset, and its select-all button flips to "Clear all" once every box is on.
  syncChips() {
    this.element.querySelectorAll("[data-facet-chip-count]").forEach((badge) => {
      const field = badge.dataset.facetChipCount
      const { checkedCount, allChecked, narrowed } = this._checkboxState(field)

      badge.textContent = narrowed ? checkedCount : ""
      badge.hidden = !narrowed
      badge.closest(".tp-facet-chip")?.classList.toggle("is-active", narrowed)

      const selectAll = this.element.querySelector(`[data-facet-select-all="${field}"]`)
      if (selectAll) selectAll.textContent = allChecked ? "Clear all" : "Select all"
    })
  }

  // Checks every box in the facet when none/some are checked, or unchecks all
  // of them when every box is already checked — mirroring the button's own
  // toggling label ("Select all" / "Clear all") computed in syncChips.
  toggleAll(event) {
    const field = event.currentTarget.dataset.facetSelectAll
    const { boxes, allChecked } = this._checkboxState(field)
    boxes.forEach((input) => { input.checked = !allChecked })
    this.submit()
  }

  _checkboxState(field) {
    const boxes = [...this.element.querySelectorAll(`input[name="${field}[]"]`)]
    const checkedCount = boxes.filter((input) => input.checked).length
    const allChecked = boxes.length > 0 && checkedCount === boxes.length
    const narrowed = checkedCount > 0 && !allChecked
    return { boxes, checkedCount, allChecked, narrowed }
  }

  search(event) {
    if (event.isComposing) return

    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.submit(), this.delayValue)
  }

  submit() {
    clearTimeout(this.timeout)
    this.syncChips()
    this.element.requestSubmit()
  }

  // Drop empty fields from the submission so URLs stay clean
  // (/?providers%5B%5D=anthropic rather than /?q=&tier=&providers...).
  clean(event) {
    for (const [name, value] of [...event.formData.entries()]) {
      if (value === "") event.formData.delete(name)
    }
  }

  // Pressing Enter in the search box submits the form natively; drop any
  // pending debounce so it doesn't fire a second, stale submission after.
  clearPending() {
    clearTimeout(this.timeout)
  }

  // The result count lives inside the frame and is replaced wholesale on
  // each render, which screen readers won't announce. Mirror it into the
  // persistent live region in the form after every frame load.
  announce(event) {
    if (event.target.id !== "models" || !this.hasStatusTarget) return

    const count = event.target.querySelector("[data-models-count]")
    if (count) this.statusTarget.textContent = count.textContent.trim()
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
