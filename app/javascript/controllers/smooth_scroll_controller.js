import { Controller } from "@hotwired/stimulus"

// Smooth-scrolls an in-page anchor link (e.g. the hero's "View models" CTA)
// via Element.scrollIntoView. Deliberately scoped to this one link rather
// than a document-wide `html { scroll-behavior: smooth }`: that would also
// catch Turbo's own internal scrollTo/scrollIntoView calls — anchor visits,
// back/forward restores, top-of-page resets on a normal visit — turning
// scrolls the reader never asked to see move into animated ones.
export default class extends Controller {
  jump(event) {
    const target = document.querySelector(this.element.getAttribute("href"))
    if (!target) return

    event.preventDefault()
    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    target.scrollIntoView({ behavior: reduceMotion ? "instant" : "smooth", block: "start" })
  }
}
