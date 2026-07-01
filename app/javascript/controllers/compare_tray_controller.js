import { Controller } from "@hotwired/stimulus"

// Drives "compare from the table". Compare is an opt-in mode: off by default,
// so a row's only affordance is "click to open the model page" (the hover
// chevron). A "Compare models" toggle outside the table reveals the per-row
// select checkboxes and switches a row click from navigate to select; picking
// two models feeds a sticky bottom tray (FIFO), which opens a head-to-head
// comparison as an in-page <dialog> + Turbo Frame loading the existing
// /compare page — no comparison logic is duplicated here.
//
// Mounted OUTSIDE turbo_frame_tag "models" on purpose: that frame re-renders
// on every filter/sort change, which would destroy and recreate a controller
// (and its selection + mode state) mounted inside it. Per-row select buttons
// and the row-click action live inside the frame and still get picked up
// automatically by Stimulus's target/action discovery — only the row
// highlighting needs a manual re-apply after a frame reload, wired
// declaratively (the same turbo:frame-load@document pattern
// filters_controller#announce uses). The mode toggle and the compare-active
// class both live on the controller element itself, outside the frame, so
// they survive reloads without any re-sync.
export default class extends Controller {
  static targets = ["tray", "slot", "compareBtn", "dialog", "frame", "removeIconTemplate", "modeBtn", "modeBtnLabel"]
  static values = {
    comparePath: String,
    compareMode: { type: Boolean, default: false },
    slugs: { type: Array, default: [] }
  }

  // ── Compare mode ─────────────────────────────────────────────────────────

  toggleMode() {
    this.compareModeValue = !this.compareModeValue
  }

  compareModeValueChanged() {
    this.element.classList.toggle("compare-active", this.compareModeValue)
    if (this.hasModeBtnTarget) {
      this.modeBtnTarget.setAttribute("aria-pressed", this.compareModeValue ? "true" : "false")
    }
    if (this.hasModeBtnLabelTarget) {
      this.modeBtnLabelTarget.textContent = this.compareModeValue ? "Done comparing" : "Compare models"
    }
    // Leaving compare mode drops any pending selection so the tray doesn't
    // linger over rows that are once again plain navigation targets.
    if (!this.compareModeValue) this.clear()
  }

  // A row click means "open the model page" normally, and "toggle selection"
  // in compare mode. The per-row select button stops propagation (see its
  // toggle:stop action), so it never double-fires with this.
  rowClick(event) {
    if (this.compareModeValue) {
      // preventDefault here also cancels navigation from any inner <a> the
      // click bubbled up through, so the whole row is a select target.
      event.preventDefault()
      const btn = event.currentTarget.querySelector(".tp-select-btn")
      if (btn) this._toggleButton(btn)
      return
    }

    // Let real links/buttons in the row (model name, provider) handle their
    // own navigation; only a click on the row's "empty" area navigates.
    if (event.target.closest("a, button")) return

    const path = event.currentTarget.dataset.modelPath
    if (!path) return
    if (window.Turbo) window.Turbo.visit(path)
    else window.location.href = path
  }

  // ── Selection ──────────────────────────────────────────────────────────────

  // data-action="click->compare-tray#toggle:stop" — the :stop suffix keeps
  // this from also firing the row-click handler.
  toggle(event) {
    this._toggleButton(event.currentTarget)
  }

  _toggleButton(btn) {
    const slug = btn.dataset.slug
    const adding = !this.slugsValue.includes(slug)

    // Cache the row's display data now, while its row is guaranteed live —
    // a selection survives filtering (by design), so the row backing it can
    // disappear from the #models frame before the tray slot next re-renders.
    // Only needed on the way in; a deselect has nothing left to render.
    if (adding) this._cacheSlotData(slug, btn)

    this.slugsValue = adding
      ? [...this.slugsValue, slug].slice(-2) // FIFO cap of 2: drop the oldest
      : this.slugsValue.filter((s) => s !== slug)
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
  // rows so a selection survives filtering. Wired via
  // data-action="turbo:frame-load@document->compare-tray#frameLoaded" on the
  // controller element; mirrors filters_controller.js's own guard.
  frameLoaded(event) {
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

  // Caches a row's display data (provider square markup + name) the moment
  // it's selected, keyed by slug — see toggle() for why this can't just be
  // re-read from the live row when a tray slot renders.
  _cacheSlotData(slug, btn) {
    this._slotData ||= new Map()
    const square = btn.closest("tr")?.querySelector(".tp-prov-sq")
    this._slotData.set(slug, {
      name: btn.dataset.name || slug,
      providerName: btn.dataset.providerName || "",
      squareHTML: square?.outerHTML
    })
  }

  // Builds the tray slot's contents from the cached selection-time data —
  // the row backing a still-selected slug may no longer be in the #models
  // frame (filtering doesn't clear a selection), so the cache, not a live
  // DOM lookup, is the single source of truth here.
  _buildSlotContent(slug) {
    const data = this._slotData?.get(slug) || { name: slug, providerName: "" }
    const wrap = document.createElement("span")
    wrap.className = "tp-tray-slot-content"

    if (data.squareHTML) wrap.insertAdjacentHTML("beforeend", data.squareHTML)

    const info = document.createElement("span")
    info.className = "tp-tray-slot-info"
    const name = document.createElement("span")
    name.className = "tp-tray-slot-name"
    name.textContent = data.name
    const provider = document.createElement("span")
    provider.className = "tp-tray-slot-provider"
    provider.textContent = data.providerName
    info.append(name, provider)
    wrap.append(info)

    const removeBtn = document.createElement("button")
    removeBtn.type = "button"
    removeBtn.className = "tp-tray-slot-remove"
    removeBtn.setAttribute("aria-label", `Remove ${data.name}`)
    removeBtn.dataset.slug = slug
    removeBtn.dataset.action = "click->compare-tray#remove"
    removeBtn.append(this.removeIconTemplateTarget.content.cloneNode(true))
    wrap.append(removeBtn)

    return wrap
  }

  // ── Dialog ─────────────────────────────────────────────────────────────────

  openCompare() {
    if (this.slugsValue.length < 2 || this.dialogTarget.open) return

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
