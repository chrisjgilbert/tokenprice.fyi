import { Controller } from "@hotwired/stimulus"

// Dims every provider line and end-label except the one being hovered — over a
// legend chip or the line itself — so a ten-line chart stays legible. The chart
// is fully readable without this; it only adds emphasis on pointer.
export default class extends Controller {
  highlight({ currentTarget }) {
    this.apply(currentTarget.dataset.provider)
  }

  reset() {
    this.apply(null)
  }

  apply(slug) {
    this.marks.forEach((el) =>
      el.classList.toggle("is-dim", Boolean(slug) && el.dataset.provider !== slug))
  }

  get marks() {
    return this.element.querySelectorAll("[data-provider]")
  }
}
