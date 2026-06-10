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
  }

  search() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.submit(), this.delayValue)
  }

  submit() {
    clearTimeout(this.timeout)
    this.element.requestSubmit()
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
