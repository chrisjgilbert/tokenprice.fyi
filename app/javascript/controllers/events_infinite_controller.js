import { Controller } from "@hotwired/stimulus"

// Infinite scroll for the market-events timeline. A sentinel below the list
// loads the next page — as a Turbo Stream that appends the next year groups and
// swaps in the following sentinel — once it nears the viewport. A year split
// across a page boundary arrives as a second year group; it is merged into the
// existing one so the year keeps a single sticky header, list, and spine. With
// JS off (or no IntersectionObserver) the sentinel's "Load more" link is a plain
// navigation to the cumulative next page.
export default class extends Controller {
  static targets = ["timeline", "sentinel", "yearGroup"]

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

  // Fires as each year group is inserted — including the ones Turbo appends for
  // later pages. When a page boundary splits a year, its second group lands with
  // a year that already exists; fold the new rows into the existing group and
  // drop the duplicate. Driven by connection rather than a post-fetch call so it
  // can't race Turbo's (asynchronous) stream render.
  yearGroupTargetConnected(group) {
    const twin = this.yearGroupTargets.find(
      (other) => other !== group && other.dataset.year === group.dataset.year
    )
    if (!twin) return
    twin.querySelector(".ev-list").append(...group.querySelector(".ev-list").children)
    group.remove()
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
      // A successful stream swaps this sentinel for the next one (or the end cap)
      // and appends the next year groups, which connect and merge themselves.
      window.Turbo.renderStreamMessage(await response.text())
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

  disconnect() {
    this.observer?.disconnect()
    this.observer = null
  }
}
