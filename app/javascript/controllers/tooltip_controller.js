import { Controller } from "@hotwired/stimulus"

// A custom tooltip for elements wearing data-controller="tooltip" and a
// data-tooltip-text-value. The bubble is a single node portaled to <body>, so
// it's never clipped by an ancestor's overflow (the filters card hides its own
// overflow for rounded corners). Shows on hover and on keyboard focus, sits
// above the target, and flips below when there isn't room. Screen readers get
// the same text via the target's own aria-describedby, independent of this.
let bubble

function tooltipBubble() {
  if (!bubble) {
    bubble = document.createElement("div")
    bubble.className = "tp-tooltip"
    document.body.appendChild(bubble)
  }
  return bubble
}

export default class extends Controller {
  static values = { text: String }

  connect() {
    this.show = this.show.bind(this)
    this.hide = this.hide.bind(this)
    this.element.addEventListener("mouseenter", this.show)
    this.element.addEventListener("mouseleave", this.hide)
    this.element.addEventListener("focusin", this.show)
    this.element.addEventListener("focusout", this.hide)
  }

  disconnect() {
    this.element.removeEventListener("mouseenter", this.show)
    this.element.removeEventListener("mouseleave", this.hide)
    this.element.removeEventListener("focusin", this.show)
    this.element.removeEventListener("focusout", this.hide)
    this.hide()
  }

  show() {
    if (!this.textValue) return
    const el = tooltipBubble()
    el.textContent = this.textValue
    this.position(el)
    el.dataset.show = "true"
    window.addEventListener("scroll", this.hide, { passive: true })
  }

  hide() {
    window.removeEventListener("scroll", this.hide)
    if (bubble) delete bubble.dataset.show
  }

  // Centre over the target, clamp within the viewport, flip below when the
  // bubble wouldn't clear the top edge. Coordinates are document-relative
  // because the bubble is absolutely positioned on <body>.
  position(el) {
    const gap = 8
    const margin = 8
    const target = this.element.getBoundingClientRect()
    const { width, height } = el.getBoundingClientRect()

    const below = target.top - height - gap < margin
    const top = below ? target.bottom + gap : target.top - height - gap
    const center = target.left + target.width / 2 - width / 2
    const left = Math.max(margin, Math.min(center, window.innerWidth - width - margin))

    el.style.left = `${left + window.scrollX}px`
    el.style.top = `${top + window.scrollY}px`
  }
}
