import { Controller } from "@hotwired/stimulus"

const STEP_LABELS = ["Client", "Scope", "Pricing", "Terms", "Review"]
const LAST_STEP = STEP_LABELS.length

// Guided quotation editor: every step lives in one form, so switching steps never
// discards typed input. Leaving the page with unsaved changes asks first.
export default class extends Controller {
  static targets = [
    "panel",
    "tab",
    "stepField",
    "backButton",
    "saveContinueButton",
    "nextButton",
    "footerStepLabel",
    "footerStepName",
    "dirtyNote",
    "workflow"
  ]

  static values = {
    step: { type: Number, default: 1 },
    editable: Boolean
  }

  connect() {
    this.dirty = false
    this.submitting = false
    this.showStep(this.stepValue, { focus: false })
    if (this.editableValue) {
      this.element.addEventListener("input", this.markDirty)
      this.element.addEventListener("change", this.markDirty)
      this.element.addEventListener("quote-pricing:changed", this.markDirty)
    }
    window.addEventListener("beforeunload", this.handleBeforeUnload)
    document.addEventListener("turbo:before-visit", this.handleBeforeVisit)
  }

  disconnect() {
    window.removeEventListener("beforeunload", this.handleBeforeUnload)
    document.removeEventListener("turbo:before-visit", this.handleBeforeVisit)
  }

  markDirty = (event) => {
    if (event?.target?.closest?.("form")?.id !== "quote-editor-form" && event?.type !== "quote-pricing:changed") return
    if (this.dirty) return
    this.dirty = true
    if (this.hasDirtyNoteTarget) this.dirtyNoteTarget.textContent = "You have unsaved changes."
  }

  clearDirty(event) {
    this.submitting = false
    if (event?.detail?.success === false) return
    this.dirty = false
  }

  beforeSubmit() {
    this.submitting = true
  }

  handleBeforeUnload = (event) => {
    if (!this.dirty || this.submitting) return
    event.preventDefault()
    event.returnValue = ""
  }

  handleBeforeVisit = (event) => {
    if (!this.dirty || this.submitting) return
    if (!window.confirm("You have unsaved changes to this quotation. Leave without saving?")) {
      event.preventDefault()
    }
  }

  goBack(event) {
    event.preventDefault()
    this.showStep(Math.max(this.stepValue - 1, 1))
  }

  goNext(event) {
    event.preventDefault()
    this.showStep(Math.min(this.stepValue + 1, LAST_STEP))
  }

  jumpToStep(event) {
    event.preventDefault()
    const next = Number(event.currentTarget.dataset.step)
    if (!Number.isNaN(next)) this.showStep(next)
  }

  showStep(step, { focus = true } = {}) {
    this.stepValue = step
    if (this.hasStepFieldTarget) this.stepFieldTarget.value = step
    this.panelTargets.forEach((panel) => {
      panel.toggleAttribute("hidden", Number(panel.dataset.step) !== step)
    })
    this.tabTargets.forEach((tab) => {
      const tabStep = Number(tab.dataset.step)
      const selected = tabStep === step
      tab.setAttribute("aria-selected", selected ? "true" : "false")
      tab.classList.toggle("staff-editor-step__tab--current", selected)
      tab.classList.toggle("staff-editor-step__tab--complete", tabStep < step)
    })
    if (this.hasWorkflowTarget) this.workflowTarget.hidden = step !== LAST_STEP
    if (this.hasBackButtonTarget) this.backButtonTarget.hidden = step === 1
    if (this.hasSaveContinueButtonTarget) this.saveContinueButtonTarget.hidden = step >= LAST_STEP
    if (this.hasNextButtonTarget) this.nextButtonTarget.hidden = step >= LAST_STEP
    if (this.hasFooterStepLabelTarget) this.footerStepLabelTarget.textContent = `Step ${step} of ${LAST_STEP}`
    if (this.hasFooterStepNameTarget) this.footerStepNameTarget.textContent = STEP_LABELS[step - 1] || ""
    if (focus) this.element.querySelector(`#quote-step-heading-${step}`)?.focus()
  }
}
