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

  // Mirror the cache-rate value live as the slider moves. The submit itself
  // fires once on release via a separate change->submit action, so dragging
  // doesn't also queue a redundant debounced submit.
  cache(event) {
    if (this.hasCacheValueTarget) this.cacheValueTarget.textContent = `${event.target.value}%`
  }

  // Live token readout for the embed's exponential sliders (display only — the
  // server is authoritative for the actual cost). Mirrors cost_estimate.rb's
  // embed_tokens / CostFormat.kfmt.
  token(event) {
    const out = event.target.closest(".emb-field")?.querySelector(".emb-v")
    if (!out) return
    const MIN = 50, MAX = 200000
    const pos = Number(event.target.value)
    const tok = pos <= 0 ? 0 : Math.round((MIN * (MAX / MIN) ** (pos / 100)) / 10) * 10
    out.textContent = tok >= 1000 ? `${(tok / 1000).toFixed(tok % 1000 ? 1 : 0)}K` : `${tok}`
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
