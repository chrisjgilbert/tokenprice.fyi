import { Controller } from "@hotwired/stimulus"

// A custom tooltip for elements wearing data-controller="tooltip" and a
// data-tooltip-text-value. The bubble is a single node portaled to <body>, so
// it's never clipped by an ancestor's overflow (the filters card hides its own
// overflow for rounded corners). Positioned in JS: centred over the target,
// clamped to the viewport, flipped below when there isn't room above.
//
// Pointer and keyboard get hover/focus. Touch is different: there's no hover,
// and tapping a pill doesn't reliably hold focus, so a focus-driven tooltip
// flashes and dies. So on touch we show it on tap and auto-dismiss — the same
// tap also applies the filter, and the body-portaled bubble outlives the
// frame reload that follows. Screen readers get the text from the target's
// aria-describedby regardless.
let bubble
let hideTimer

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
    this.onEnter = () => { if (!this.touched) this.show() }
    this.onLeave = () => { if (!this.touched) this.hide() }
    this.onTap = () => { this.touched = true; this.show(2500) }

    this.element.addEventListener("mouseenter", this.onEnter)
    this.element.addEventListener("mouseleave", this.onLeave)
    this.element.addEventListener("focusin", this.onEnter)
    this.element.addEventListener("focusout", this.onLeave)
    this.element.addEventListener("touchstart", this.onTap, { passive: true })
  }

  disconnect() {
    this.element.removeEventListener("mouseenter", this.onEnter)
    this.element.removeEventListener("mouseleave", this.onLeave)
    this.element.removeEventListener("focusin", this.onEnter)
    this.element.removeEventListener("focusout", this.onLeave)
    this.element.removeEventListener("touchstart", this.onTap)
    this.hide()
  }

  show(autoHideMs) {
    if (!this.textValue) return
    clearTimeout(hideTimer)
    const el = tooltipBubble()
    el.textContent = this.textValue
    this.position(el)
    el.dataset.show = "true"
    if (autoHideMs) hideTimer = setTimeout(() => this.hide(), autoHideMs)
  }

  hide() {
    clearTimeout(hideTimer)
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
