import { Controller } from "@hotwired/stimulus"

// Category tab switches are full Turbo visits — each tab is its own indexable
// URL — so the browser resets scroll to the top, above a tall hero the reader
// then has to scroll back past. Capture the scroll position when a tab is
// clicked and restore it once the next page connects. Keyed one-shot in
// sessionStorage so it only fires for tab-to-tab navigation, never a fresh
// arrival or a browser back/forward (which Turbo restores natively).
export default class extends Controller {
  static key = "tp-tab-scroll"

  connect() {
    const saved = sessionStorage.getItem(this.constructor.key)
    if (saved !== null) {
      sessionStorage.removeItem(this.constructor.key)
      window.scrollTo(0, parseInt(saved, 10))
    }
  }

  save() {
    sessionStorage.setItem(this.constructor.key, window.scrollY)
  }
}
