import { Controller } from "@hotwired/stimulus"

const AMOUNT_PATTERN = /^(\d{1,3}(,\d{3})+|\d+)(\.\d{1,2})?$/
const QUANTITY_PATTERN = /^\d+(\.\d{1,3})?$/

// Pricing lines for the quotation editor. Estimates use integer minor units
// (BigInt) so the preview matches the server's BigDecimal calculation.
export default class extends Controller {
  static targets = ["list", "row", "template", "empty", "position", "destroy", "number",
    "quantity", "price", "lineTotal", "total", "totalNote", "currency", "currencyLabel"]

  static values = { currency: String }

  connect() {
    this.counter = 0
    this.renumber()
  }

  add(event) {
    event.preventDefault()
    const key = `${Date.now()}${this.counter++}`
    const html = this.templateTarget.innerHTML.replaceAll("NEW_LINE_KEY", key)
    this.listTarget.insertAdjacentHTML("beforeend", html)
    this.renumber()
    this.recalculate()
    this.changed()
    const rows = this.activeRows()
    rows[rows.length - 1]?.querySelector("input[name$='[description]']")?.focus()
  }

  remove(event) {
    event.preventDefault()
    const row = event.currentTarget.closest("[data-quote-pricing-target='row']")
    if (!row) return
    if (row.dataset.persisted === "true") {
      row.querySelector("[data-quote-pricing-target='destroy']").value = "1"
      row.hidden = true
      row.dataset.removed = "true"
    } else {
      row.remove()
    }
    this.renumber()
    this.recalculate()
    this.changed()
  }

  moveUp(event) {
    event.preventDefault()
    const row = event.currentTarget.closest("[data-quote-pricing-target='row']")
    const rows = this.activeRows()
    const index = rows.indexOf(row)
    if (index > 0) rows[index - 1].before(row)
    this.afterMove(event)
  }

  moveDown(event) {
    event.preventDefault()
    const row = event.currentTarget.closest("[data-quote-pricing-target='row']")
    const rows = this.activeRows()
    const index = rows.indexOf(row)
    if (index >= 0 && index < rows.length - 1) rows[index + 1].after(row)
    this.afterMove(event)
  }

  afterMove(event) {
    this.renumber()
    this.changed()
    event.currentTarget.focus()
  }

  activeRows() {
    return this.rowTargets.filter((row) => row.dataset.removed !== "true")
  }

  renumber() {
    const rows = this.activeRows()
    rows.forEach((row, index) => {
      const position = row.querySelector("[data-quote-pricing-target='position']")
      if (position) position.value = index
      const number = row.querySelector("[data-quote-pricing-target='number']")
      if (number) number.textContent = `Pricing line ${index + 1}`
    })
    if (this.hasEmptyTarget) this.emptyTarget.hidden = rows.length > 0
  }

  recalculate() {
    const currency = this.hasCurrencyTarget ? this.currencyTarget.value : this.currencyValue
    this.currencyLabelTargets.forEach((label) => { label.textContent = currency })
    let total = 0n
    let complete = true
    this.activeRows().forEach((row) => {
      const qty = this.parseQuantity(row.querySelector("[data-quote-pricing-target='quantity']")?.value)
      const price = this.parseAmount(row.querySelector("[data-quote-pricing-target='price']")?.value)
      const output = row.querySelector("[data-quote-pricing-target='lineTotal']")
      if (qty === null || price === null) {
        complete = false
        if (output) output.textContent = "Check quantity and price"
        return
      }
      const line = (qty * price + 500n) / 1000n
      total += line
      if (output) output.textContent = this.format(line, currency)
    })
    if (this.hasTotalTarget) this.totalTarget.textContent = this.format(total, currency)
    if (this.hasTotalNoteTarget) {
      this.totalNoteTarget.textContent = complete
        ? "Estimated from the lines above. The total is confirmed when you save."
        : "Some lines need a valid quantity and price before the total is accurate."
    }
  }

  // Quantity in thousandths, e.g. "1.5" -> 1500n
  parseQuantity(raw) {
    const text = (raw || "").trim()
    if (!QUANTITY_PATTERN.test(text)) return null
    const [whole, fraction = ""] = text.split(".")
    const value = BigInt(whole) * 1000n + BigInt(fraction.padEnd(3, "0"))
    return value > 0n ? value : null
  }

  // Amount in minor units, e.g. "1,250.5" -> 125050n; blank counts as zero
  parseAmount(raw) {
    const text = (raw || "").trim().replaceAll(" ", "")
    if (text === "") return 0n
    if (!AMOUNT_PATTERN.test(text)) return null
    const [whole, fraction = ""] = text.replaceAll(",", "").split(".")
    return BigInt(whole) * 100n + BigInt(fraction.padEnd(2, "0"))
  }

  format(minor, currency) {
    const whole = (minor / 100n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",")
    const fraction = (minor % 100n).toString().padStart(2, "0")
    return `${currency} ${whole}.${fraction}`
  }

  changed() {
    this.dispatch("changed", { bubbles: true, prefix: "quote-pricing" })
  }
}
