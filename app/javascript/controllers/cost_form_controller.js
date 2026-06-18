import { Controller } from "@hotwired/stimulus"

// Drives the live estimator: a debounced Turbo-Frame submit while typing in the
// token/volume fields, immediate on the cache slider / tier / baseline changes.
// The form carries data-turbo-frame="cost_result" + data-turbo-action="replace",
// so each submit refreshes the result frame and keeps the URL a shareable
// permalink. A near-clone of filters_controller. The math is all server-side.
export default class extends Controller {
  static targets = ["cacheValue"]
  static values = { delay: { type: Number, default: 350 } }

  // Debounced submit for free-text number fields.
  edit() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.submit(), this.delayValue)
  }

  // Immediate submit for discrete controls (slider release, tier, baseline).
  submit() {
    clearTimeout(this.timeout)
    this.element.requestSubmit()
  }

  // Mirror the cache-rate value as the slider moves, then debounce-submit.
  cache(event) {
    if (this.hasCacheValueTarget) this.cacheValueTarget.textContent = `${event.target.value}%`
    this.edit()
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
