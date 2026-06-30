import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "select",
    "costLine",
    "totalLine",
    "classificationSelected",
    "multiplier"
  ]
  static values = {
    models: Array,
    smallRefInput: Number,
    defaultSlug: String
  }

  connect() {
    if (this.hasSelectTarget && this.hasDefaultSlugValue && this.defaultSlugValue) {
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
