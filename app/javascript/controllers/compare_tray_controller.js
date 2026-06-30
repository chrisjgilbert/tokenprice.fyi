import { Controller } from "@hotwired/stimulus"

// Drives "compare from the table": hover-revealed select buttons on each
// table row feed a sticky bottom tray (up to 2 models, FIFO), which opens a
// head-to-head comparison as an in-page <dialog> + Turbo Frame loading the
// existing /compare page — no comparison logic is duplicated here.
//
// Mounted OUTSIDE turbo_frame_tag "models" on purpose: that frame re-renders
// on every filter/sort change, which would destroy and recreate a controller
// (and its selection state) mounted inside it. Per-row select buttons live
// inside the frame and still get picked up automatically by Stimulus's
// target/action discovery — only the row highlighting needs a manual
// re-apply after a frame reload (see frameLoaded below).
export default class extends Controller {
  static targets = ["tray", "slot", "compareBtn", "dialog", "frame"]
  static values = {
    comparePath: String,
    slugs: { type: Array, default: [] }
  }

  connect() {
    document.addEventListener("turbo:frame-load", this.frameLoaded)
  }

  disconnect() {
    document.removeEventListener("turbo:frame-load", this.frameLoaded)
  }

  // ── Selection ──────────────────────────────────────────────────────────────

  // data-action="click->compare-tray#toggle:stop" — the :stop suffix keeps
  // this from also firing the row's onclick navigation.
  toggle(event) {
    const slug = event.currentTarget.dataset.slug
    const slugs = this.slugsValue.includes(slug)
      ? this.slugsValue.filter((s) => s !== slug)
      : [...this.slugsValue, slug].slice(-2) // FIFO cap of 2: drop the oldest

    this.slugsValue = slugs
  }

  clear() {
    this.slugsValue = []
  }

  remove(event) {
    const slug = event.currentTarget.dataset.slug
    this.slugsValue = this.slugsValue.filter((s) => s !== slug)
  }

  slugsValueChanged() {
    this._syncRowState()
    this._syncTray()
  }

  // ── Row state (buttons + selected-row highlighting) ──────────────────────

  _syncRowState() {
    this.element.querySelectorAll(".tp-select-btn").forEach((btn) => {
      const selected = this.slugsValue.includes(btn.dataset.slug)
      btn.classList.toggle("is-selected", selected)
      btn.setAttribute("aria-pressed", selected ? "true" : "false")
      btn.closest("tr")?.classList.toggle("tp-row-selected", selected)
    })
  }

  // The table frame reloads wholesale on every filter/sort change, replacing
  // the row markup entirely — re-apply selected-state classes to the fresh
  // rows so a selection survives filtering. Mirrors filters_controller.js's
  // own turbo:frame-load guard.
  frameLoaded = (event) => {
    if (event.target.id !== "models") return
    this._syncRowState()
  }

  // ── Tray ───────────────────────────────────────────────────────────────────

  _syncTray() {
    const slugs = this.slugsValue
    this.trayTarget.hidden = slugs.length === 0

    this.slotTargets.forEach((slot, i) => {
      const slug = slugs[i]
      slot.replaceChildren()

      if (!slug) {
        slot.classList.remove("filled")
        const empty = document.createElement("span")
        empty.className = "tp-tray-slot-empty"
        empty.textContent = "Select a model"
        slot.append(empty)
        return
      }

      slot.classList.add("filled")
      slot.append(this._buildSlotContent(slug))
    })

    const compareBtn = this.compareBtnTarget
    compareBtn.disabled = slugs.length < 2
    compareBtn.textContent = slugs.length < 2 ? "Pick one more" : "Compare"
  }

  // Builds the tray slot's contents by cloning the matching row's own
  // provider-square markup — the row's DOM is the single source of truth for
  // model display data, so this never introduces a second copy of it.
  _buildSlotContent(slug) {
    const btn = this.element.querySelector(`.tp-select-btn[data-slug="${slug}"]`)
    const wrap = document.createElement("span")
    wrap.className = "tp-tray-slot-content"

    const square = btn?.closest("tr")?.querySelector(".tp-prov-sq")
    if (square) wrap.append(square.cloneNode(true))

    const info = document.createElement("span")
    info.className = "tp-tray-slot-info"
    const name = document.createElement("span")
    name.className = "tp-tray-slot-name"
    name.textContent = btn?.dataset.name || slug
    const provider = document.createElement("span")
    provider.className = "tp-tray-slot-provider"
    provider.textContent = btn?.dataset.providerName || ""
    info.append(name, provider)
    wrap.append(info)

    const removeBtn = document.createElement("button")
    removeBtn.type = "button"
    removeBtn.className = "tp-tray-slot-remove"
    removeBtn.setAttribute("aria-label", `Remove ${btn?.dataset.name || slug}`)
    removeBtn.dataset.slug = slug
    removeBtn.dataset.action = "click->compare-tray#remove"
    removeBtn.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>'
    wrap.append(removeBtn)

    return wrap
  }

  // ── Dialog ─────────────────────────────────────────────────────────────────

  openCompare() {
    if (this.slugsValue.length < 2) return

    const url = new URL(this.comparePathValue, window.location.origin)
    url.searchParams.set("a", this.slugsValue[0])
    url.searchParams.set("b", this.slugsValue[1])
    this.frameTarget.src = url.toString()
    this.dialogTarget.showModal()
  }

  closeDialog() {
    this.dialogTarget.close()
  }

  // Clicking the rendered ::backdrop registers as a click on the <dialog>
  // element itself with event.target === the dialog — the standard idiom for
  // backdrop-click-to-close on a native dialog.
  backdropClose(event) {
    if (event.target === event.currentTarget) this.closeDialog()
  }
}
