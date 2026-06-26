import { Controller } from "@hotwired/stimulus"

// Infinite scroll for the market-events timeline. A sentinel below the list
// loads the next page — as a Turbo Stream that appends the next year groups and
// swaps in the following sentinel — once it nears the viewport. Year groups
// split across a page boundary are merged so each year keeps a single sticky
// header and spine. With JS off (or no IntersectionObserver) the sentinel's
// "Load more" link is a plain navigation to the cumulative next page.
export default class extends Controller {
  static targets = ["timeline", "sentinel"]

  connect() {
    // Flags the fallback link off; the observer is the only trigger from here.
    this.element.setAttribute("data-events-infinite-connected", "")
  }

  sentinelTargetConnected(sentinel) {
    if (!("IntersectionObserver" in window)) return
    this.observer ||= new IntersectionObserver(
      (entries) => { if (entries.some((e) => e.isIntersecting)) this.load() },
      { rootMargin: "400px 0px" }
    )
    this.observer.observe(sentinel)
  }

  sentinelTargetDisconnected(sentinel) {
    this.observer?.unobserve(sentinel)
  }

  async load() {
    const sentinel = this.hasSentinelTarget ? this.sentinelTarget : null
    const url = sentinel?.dataset.nextUrl
    if (this.loading || !url) return

    this.loading = true
    sentinel.classList.add("is-loading")
    try {
      const response = await fetch(url, { headers: { Accept: "text/vnd.turbo-stream.html" } })
      if (!response.ok) throw new Error(`Failed to load events: ${response.status}`)
      // A successful stream swaps this sentinel for the next one (or the end
      // cap), so `sentinel` is now detached — clearing its class below is a no-op.
      window.Turbo.renderStreamMessage(await response.text())
      this.mergeYearGroups()
    } catch {
      // Stop observing the failed sentinel so one parked in view doesn't retry in
      // a tight loop, and reveal the "Load more" link (hidden while the observer
      // drives loading) so the user has a manual retry — it navigates to the same
      // next page as a full request.
      this.observer?.unobserve(sentinel)
      this.element.removeAttribute("data-events-infinite-connected")
    } finally {
      this.loading = false
      sentinel.classList.remove("is-loading")
    }
  }

  // Collapse adjacent year groups sharing a year — a year straddling a page
  // boundary arrives as a second group — into one, so it keeps a single header,
  // list, and spine.
  mergeYearGroups() {
    const kept = new Map()
    this.timelineTarget.querySelectorAll(".ev-year-group").forEach((group) => {
      const year = group.dataset.year
      const first = kept.get(year)
      if (first) {
        first.querySelector(".ev-list").append(...group.querySelector(".ev-list").children)
        group.remove()
      } else {
        kept.set(year, group)
      }
    })
  }

  disconnect() {
    this.observer?.disconnect()
    this.observer = null
  }
}
