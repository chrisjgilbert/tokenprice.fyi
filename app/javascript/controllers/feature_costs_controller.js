import { Controller } from "@hotwired/stimulus"

// Drives the interactive model picker on /learn/feature-costs. When the user
// selects a model, every cost receipt on the page recalculates using that
// model's live input/output rates. The page is fully readable without JS —
// the initial numbers are rendered server-side with a sensible default model.
export default class extends Controller {
  static targets = [
    "select",            // the <select> model picker
    "costLine",          // a single cost line (tokens × rate); needs data-tokens + data-rate-type
    "totalLine",         // a total line (sum of input + output costs); needs data-input-tokens + data-output-tokens
    "classificationSelected", // the selected-model row in the classification comparison receipt
    "multiplier"         // the "~Nx" cost-difference span in the classification comparison
  ]
  static values = {
    models: Array,       // [{slug, name, input, output}, …]
    smallRefInput: Number, // hardcoded small-tier reference rate for the classification comparison
    defaultSlug: String  // pre-selected model slug
  }

  connect() {
    if (this.hasDefaultSlugValue && this.defaultSlugValue) {
      this.selectTarget.value = this.defaultSlugValue
    }
    this.refresh()
  }

  refresh() {
    const model = this.currentModel()
    if (!model) return

    this.costLineTargets.forEach(line => {
      const tokens = parseFloat(line.dataset.tokens)
      const rate = line.dataset.rateType === "input" ? model.input : model.output
      const cost = tokens * rate / 1_000_000
      const formula = line.querySelector("[data-fc-formula]")
      const amount = line.querySelector("[data-fc-amount]")
      if (formula) formula.textContent = `${this.fmtNum(tokens)} × $${this.fmtRate(rate)} / 1M`
      if (amount) amount.textContent = this.fmtCost(cost)
    })

    this.totalLineTargets.forEach(line => {
      const inTok = parseFloat(line.dataset.inputTokens || 0)
      const outTok = parseFloat(line.dataset.outputTokens || 0)
      const cost = (inTok * model.input + outTok * model.output) / 1_000_000
      const formula = line.querySelector("[data-fc-formula]")
      const amount = line.querySelector("[data-fc-amount]")
      if (formula) formula.textContent = `$${this.fmtRate(model.input)} in / $${this.fmtRate(model.output)} out per 1M`
      if (amount) amount.textContent = this.fmtCost(cost)
    })

    this.classificationSelectedTargets.forEach(line => {
      const tokens = parseFloat(line.dataset.tokens || 803)
      const cost = tokens * model.input / 1_000_000
      const formula = line.querySelector("[data-fc-formula]")
      const amount = line.querySelector("[data-fc-amount]")
      if (formula) formula.textContent = `${this.fmtNum(tokens)} tok @ $${this.fmtRate(model.input)} in`
      if (amount) amount.textContent = this.fmtCost(cost)
    })

    if (this.hasMultiplierTarget && this.smallRefInputValue > 0) {
      const smallCost = 803 * this.smallRefInputValue / 1_000_000
      const selCost   = 803 * model.input / 1_000_000
      const mult = selCost > 0 && smallCost > 0 ? Math.round(selCost / smallCost) : "?"
      this.multiplierTargets.forEach(el => el.textContent = `~${mult}×`)
    }
  }

  currentModel() {
    const slug = this.hasSelectTarget ? this.selectTarget.value : null
    return this.modelsValue.find(m => m.slug === slug) || this.modelsValue[0]
  }

  // Matches PriceFormat: dollar+ gets 2 dp; sub-dollar gets up to 4 dp trimmed.
  fmtRate(rate) {
    if (rate === null || rate === undefined) return "—"
    const r = parseFloat(rate)
    if (r >= 1) return r.toFixed(2)
    return r.toFixed(4).replace(/0+$/, "").replace(/\.$/, "")
  }

  fmtNum(n) {
    return n.toLocaleString("en-US")
  }

  fmtCost(cost) {
    if (cost === 0) return "$0"
    if (cost < 1) return "$" + cost.toFixed(5).replace(/0+$/, "").replace(/\.$/, "")
    return "$" + cost.toFixed(2)
  }
}
