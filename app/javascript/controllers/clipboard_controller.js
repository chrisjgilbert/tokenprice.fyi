import { Controller } from "@hotwired/stimulus"

// Copies the current permalink (the URL already encodes the workload) and
// briefly flips the button to a confirmation — the "Link copied ✓" state.
export default class extends Controller {
  static targets = ["label"]

  copy() {
    const url = window.location.href
    navigator.clipboard?.writeText(url).then(() => this.flip()).catch(() => {})
  }

  flip() {
    if (!this.hasLabelTarget) return

    this.element.classList.add("is-ok")
    const prev = this.labelTarget.textContent
    this.labelTarget.textContent = "Link copied"
    clearTimeout(this.timer)
    this.timer = setTimeout(() => {
      this.element.classList.remove("is-ok")
      this.labelTarget.textContent = prev
    }, 1800)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
