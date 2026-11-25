import { Controller } from "@hotwired/stimulus"

// Progressive enhancement for the public request-a-quote form. Without JavaScript
// every step stays visible and the form submits normally; the server re-renders the
// same form, with the visitor's answers, when anything needs correcting.
export default class extends Controller {
  static targets = ["panel", "indicator", "summaryItem", "nav", "form", "submit", "alert", "choice"]
  static values = { step: { type: Number, default: 1 }, total: { type: Number, default: 4 } }

  connect() {
    this.element.classList.add("is-enhanced")
    if (this.hasFormTarget) this.formTarget.noValidate = true
    this.navTargets.forEach((nav) => { nav.hidden = false })
    this.showStep(this.stepValue, { scroll: false })
    if (this.hasAlertTarget) this.alertTarget.focus()
  }

  next() {
    const panel = this.panelFor(this.stepValue)
    if (!this.validatePanel(panel)) return
    this.showStep(Math.min(this.stepValue + 1, this.totalValue))
  }

  back() {
    this.showStep(Math.max(this.stepValue - 1, 1))
  }

  reveal(event) {
    const id = (event.currentTarget.getAttribute("href") || "").replace(/^#/, "")
    const target = id && document.getElementById(id)
    if (!target) return
    event.preventDefault()
    const panel = target.closest("[data-enquiry-wizard-target~='panel']")
    if (panel) this.showStep(Number(panel.dataset.step))
    const focusable = target.matches("input, textarea, select") ? target : target.querySelector("input, textarea, select")
    focusable?.focus()
  }

  submit(event) {
    if (this.submitting) {
      event.preventDefault()
      return
    }
    const invalidPanel = this.panelTargets.find((panel) => !this.fieldsIn(panel).every((field) => field.checkValidity()))
    if (invalidPanel) {
      event.preventDefault()
      this.showStep(Number(invalidPanel.dataset.step))
      this.validatePanel(invalidPanel)
      return
    }
    this.submitting = true
    if (this.hasSubmitTarget) {
      this.submitTarget.setAttribute("aria-disabled", "true")
      this.submitTarget.textContent = "Sending…"
    }
  }

  showStep(step, { scroll = true } = {}) {
    this.stepValue = step
    this.panelTargets.forEach((panel) => { panel.hidden = Number(panel.dataset.step) !== step })
    this.indicatorTargets.forEach((item) => {
      const number = Number(item.dataset.step)
      item.classList.toggle("is-current", number === step)
      item.classList.toggle("is-done", number < step)
      if (number === step) item.setAttribute("aria-current", "step")
      else item.removeAttribute("aria-current")
    })
    this.summaryItemTargets.forEach((item) => this.updateBadge(item, Number(item.dataset.step), step))
    if (step === this.totalValue) this.updateReview()
    if (scroll) {
      this.element.scrollIntoView({ behavior: "smooth", block: "start" })
      const heading = this.panelFor(step)?.querySelector("legend, h2")
      if (heading) {
        heading.setAttribute("tabindex", "-1")
        heading.focus({ preventScroll: true })
      }
    }
  }

  updateBadge(item, number, step) {
    const badge = item.querySelector("[data-role='badge']")
    if (!badge) return
    const state = number < step ? ["Done", "ant-badge--good"] : number === step ? ["Now", "ant-badge--teal"] : ["Next", "ant-badge--muted"]
    badge.textContent = state[0]
    badge.className = `ant-badge ${state[1]}`
  }

  updateReview() {
    this.element.querySelectorAll("[data-review-for]").forEach((cell) => {
      const source = cell.dataset.reviewFor
      let value = ""
      if (source === "service_choice") {
        value = this.choiceTargets.find((choice) => choice.checked)?.dataset.reviewValue || ""
      } else {
        const field = document.getElementById(source)
        value = field ? field.value.trim() : ""
        if (value && field.type === "date") {
          const date = new Date(`${value}T00:00:00`)
          if (!Number.isNaN(date.getTime())) value = date.toLocaleDateString(undefined, { day: "numeric", month: "long", year: "numeric" })
        }
      }
      cell.textContent = value || "Not provided"
    })
  }

  validatePanel(panel) {
    if (!panel) return true
    const invalid = this.fieldsIn(panel).find((field) => !field.checkValidity())
    if (!invalid) return true
    invalid.reportValidity()
    invalid.focus()
    return false
  }

  fieldsIn(panel) {
    return Array.from(panel.querySelectorAll("input, textarea, select")).filter((field) => field.type !== "hidden")
  }

  panelFor(step) {
    return this.panelTargets.find((panel) => Number(panel.dataset.step) === step)
  }
}
