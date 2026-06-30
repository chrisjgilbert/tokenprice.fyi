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
  connect() {
    const params = new URLSearchParams(window.location.search)
    const providers = params.getAll("providers[]")

    this.element.querySelectorAll("input").forEach((input) => {
      if (input.type === "checkbox") {
        input.checked = providers.includes(input.value)
      } else if (input.type === "radio") {
        input.checked = (params.get(input.name) || "") === input.value
      } else if (input.type === "search" || input.type === "text") {
        input.value = params.get(input.name) || ""
      }
    })

    this.syncChips()
  }

  // Keep the facet dropdown chips in step with the controls inside their
  // panels: the chips live outside the Turbo frame, so nothing else refreshes
  // them. The tier/modality chips echo the chosen value; the provider chip
  // shows a count badge when the selection is narrowed to a proper subset.
  syncChips() {
    this.element.querySelectorAll("[data-facet-chip]").forEach((slot) => {
      const checked = this.element.querySelector(`input[name="${slot.dataset.facetChip}"]:checked`)
      const value = checked?.value
      const label = value ? checked.closest(".tp-pill")?.textContent.trim() : ""
      slot.textContent = label ? ` · ${label}` : ""
      slot.closest(".tp-facet-chip")?.classList.toggle("is-active", Boolean(value))
    })

    // No boxes checked means "all providers" (the form omits an empty filter),
    // so the chip is only narrowed for a proper, non-empty subset.
    const providers = [...this.element.querySelectorAll('input[name="providers[]"]')]
    const checkedCount = providers.filter((input) => input.checked).length
    const narrowed = checkedCount > 0 && checkedCount < providers.length

    const badge = this.element.querySelector('[data-facet-chip-count="provider"]')
    if (badge) {
      badge.textContent = narrowed ? checkedCount : ""
      badge.hidden = !narrowed
      badge.closest(".tp-facet-chip")?.classList.toggle("is-active", narrowed)
    }

    const allChecked = checkedCount === providers.length
    const selectAllButton = this.element.querySelector(".tp-facet-panel-action")
    if (selectAllButton) selectAllButton.textContent = allChecked ? "Clear all" : "Select all"
  }

  // Checks every providers[] box when none/some are checked, or unchecks all
  // of them when every box is already checked — mirroring the button's own
  // toggling label ("Select all" / "Clear all") computed in syncChips.
  toggleAllProviders() {
    const providers = [...this.element.querySelectorAll('input[name="providers[]"]')]
    const allChecked = providers.every((input) => input.checked)
    providers.forEach((input) => { input.checked = !allChecked })
    this.submit()
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
