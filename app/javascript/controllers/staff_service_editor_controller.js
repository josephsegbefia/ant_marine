import { Controller } from "@hotwired/stimulus"

const STEP_LABELS = ["Basics", "Details", "Scope & process", "Review"]

export default class extends Controller {
  static targets = [
    "panel",
    "tab",
    "stepField",
    "errorSummary",
    "errorList",
    "titleField",
    "suggestedPath",
    "previewTitle",
    "previewSummary",
    "previewBody",
    "previewAudience",
    "previewScopeList",
    "previewProcess",
    "previewUrl",
    "previewSeoTitle",
    "previewSeoDescription",
    "missingList",
    "backButton",
    "saveContinueButton",
    "submitReviewBlock",
    "footerStepLabel",
    "footerStepName"
  ]

  static values = {
    step: { type: Number, default: 1 },
    newRecord: Boolean,
    published: Boolean,
    savedSlug: String
  }

  connect() {
    this.dirty = false
    this.showStep(this.stepValue)
    this.refreshPreview()
    this.element.addEventListener("input", () => this.markDirty())
    this.element.addEventListener("trix-change", () => this.markDirty())
    this.element.addEventListener("staff-list-editor:changed", () => {
      this.markDirty()
      this.refreshPreview()
    })
    window.addEventListener("beforeunload", this.handleBeforeUnload)
  }

  disconnect() {
    window.removeEventListener("beforeunload", this.handleBeforeUnload)
  }

  handleBeforeUnload = (event) => {
    if (!this.dirty) return
    event.preventDefault()
    event.returnValue = ""
  }

  markDirty() {
    this.dirty = true
    this.refreshPreview()
  }

  clearDirty() {
    this.dirty = false
  }

  validateBeforeSubmit(event) {
    const commit = event.submitter?.value
    if (commit === "save_draft") {
      if (!this.titleFieldTarget.value.trim()) {
        event.preventDefault()
        this.showErrors(["Enter a service name to save this draft."])
        this.titleFieldTarget.focus()
      }
      return
    }
    if (commit === "save_continue") {
      const result = this.validateStep(this.stepValue)
      if (!result.ok) {
        event.preventDefault()
        this.showErrors(result.messages)
        this.focusFirstInvalid()
      }
    }
  }

  goBack(event) {
    event.preventDefault()
    this.clearErrors()
    this.showStep(Math.max(this.stepValue - 1, 1))
  }

  jumpToStep(event) {
    event.preventDefault()
    const next = Number(event.currentTarget.dataset.step)
    if (Number.isNaN(next)) return
    if (next > this.stepValue) {
      const result = this.validateStep(this.stepValue)
      if (!result.ok) {
        this.showErrors(result.messages)
        return
      }
    }
    this.clearErrors()
    this.showStep(next)
  }

  showStep(step) {
    this.stepValue = step
    if (this.hasStepFieldTarget) this.stepFieldTarget.value = step
    this.panelTargets.forEach((panel) => {
      const active = Number(panel.dataset.step) === step
      panel.toggleAttribute("hidden", !active)
    })
    this.tabTargets.forEach((tab) => {
      const tabStep = Number(tab.dataset.step)
      const selected = tabStep === step
      tab.setAttribute("aria-selected", selected ? "true" : "false")
      tab.classList.toggle("staff-editor-step__tab--current", selected)
      tab.classList.toggle("staff-editor-step__tab--complete", tabStep < step)
    })
    const heading = this.element.querySelector(`#editor-step-heading-${step}`)
    heading?.focus()
    this.syncFooter(step)
  }

  syncFooter(step) {
    if (this.hasBackButtonTarget) {
      this.backButtonTarget.hidden = step === 1
    }
    if (this.hasSaveContinueButtonTarget) {
      this.saveContinueButtonTarget.hidden = step >= 4
    }
    if (this.hasSubmitReviewBlockTarget) {
      this.submitReviewBlockTarget.hidden = step !== 4
    }
    if (this.hasFooterStepLabelTarget) {
      this.footerStepLabelTarget.textContent = `Step ${step} of 4`
    }
    if (this.hasFooterStepNameTarget) {
      this.footerStepNameTarget.textContent = STEP_LABELS[step - 1] || ""
    }
  }

  validateStep(step) {
    const messages = []
    if (step === 1) {
      if (!this.titleFieldTarget.value.trim()) messages.push("Enter a service name to continue.")
      if (!this.fieldValue("summary").trim()) messages.push("Add a short description so visitors understand what this service offers.")
    }
    if (step === 2) {
      if (!this.bodyHasText(this.fieldValue("body"))) messages.push("Describe what this service involves before continuing.")
      if (!this.fieldValue("audience").trim()) messages.push("Tell us who this service is for.")
    }
    return { ok: messages.length === 0, messages }
  }

  showErrors(messages) {
    if (!this.hasErrorSummaryTarget) return
    this.errorSummaryTarget.hidden = false
    this.errorListTarget.replaceChildren()
    messages.forEach((message) => {
      const li = document.createElement("li")
      li.textContent = message
      this.errorListTarget.appendChild(li)
    })
    this.errorSummaryTarget.focus()
  }

  clearErrors() {
    if (this.hasErrorSummaryTarget) this.errorSummaryTarget.hidden = true
  }

  focusFirstInvalid() {
    if (this.stepValue === 1) {
      if (!this.titleFieldTarget.value.trim()) return this.titleFieldTarget.focus()
      if (!this.fieldValue("summary").trim()) return this.element.querySelector("#service_summary")?.focus()
    }
  }

  titleInput() {
    this.markDirty()
    if (!this.hasSuggestedPathTarget || !this.newRecordValue) return
    const slug = this.slugify(this.titleFieldTarget.value)
    this.suggestedPathTarget.textContent = slug
      ? `Likely address after save: /services/${slug}`
      : "We will assign an address when you save this draft."
  }

  refreshPreview() {
    if (this.hasPreviewTitleTarget) this.previewTitleTarget.textContent = this.titleFieldTarget.value.trim() || "Service title"
    if (this.hasPreviewSummaryTarget) this.previewSummaryTarget.textContent = this.fieldValue("summary") || "Short description will appear here."
    if (this.hasPreviewBodyTarget) {
      const bodyHtml = this.fieldValue("body")
      if (bodyHtml.trim() && this.bodyHasText(bodyHtml)) {
        this.previewBodyTarget.classList.add("public-rich-text")
        this.previewBodyTarget.innerHTML = bodyHtml
      } else {
        this.previewBodyTarget.classList.remove("public-rich-text")
        this.previewBodyTarget.textContent = "Your full explanation will appear here."
      }
    }
    if (this.hasPreviewAudienceTarget) this.previewAudienceTarget.textContent = this.fieldValue("audience") || "Intended audience"
    if (this.hasPreviewScopeListTarget) {
      const items = this.listValues("scope_items")
      this.previewScopeListTarget.replaceChildren()
      if (items.length === 0) {
        const li = document.createElement("li")
        li.textContent = "Scope items will be listed here."
        this.previewScopeListTarget.appendChild(li)
      } else {
        items.forEach((item) => {
          const li = document.createElement("li")
          li.textContent = item
          this.previewScopeListTarget.appendChild(li)
        })
      }
    }
    if (this.hasPreviewProcessTarget) {
      const steps = this.listValues("process_steps")
      this.previewProcessTarget.textContent = steps.length > 0 ? steps.join(" → ") : "Process steps will appear here."
    }
    if (this.hasPreviewUrlTarget) {
      const slug = this.savedSlugValue || this.slugify(this.titleFieldTarget.value)
      this.previewUrlTarget.textContent = slug ? `/services/${slug}` : "Page address is assigned when you save"
    }
    if (this.hasPreviewSeoTitleTarget) {
      const seoTitle = this.fieldValue("seo_title")
      this.previewSeoTitleTarget.textContent = seoTitle || this.titleFieldTarget.value.trim() || "Page title for search"
    }
    if (this.hasPreviewSeoDescriptionTarget) {
      const seoDesc = this.fieldValue("seo_description")
      this.previewSeoDescriptionTarget.textContent = seoDesc || this.fieldValue("summary") || "Search description preview"
    }
    if (this.hasMissingListTarget) {
      this.missingListTarget.replaceChildren()
      const missing = this.computeMissing()
      missing.forEach((label) => {
        const li = document.createElement("li")
        li.textContent = label
        this.missingListTarget.appendChild(li)
      })
      this.missingListTarget.closest("[data-staff-service-editor-target='missingPanel']")?.toggleAttribute("hidden", missing.length === 0)
    }
  }

  computeMissing() {
    const missing = []
    if (!this.titleFieldTarget.value.trim()) missing.push("Service name")
    if (!this.fieldValue("summary").trim()) missing.push("Short description")
    if (!this.bodyHasText(this.fieldValue("body"))) missing.push("Full explanation")
    if (!this.fieldValue("audience").trim()) missing.push("Intended audience")
    if (!this.listValues("scope_items").length) missing.push("What's included")
    if (!this.listValues("process_steps").length) missing.push("Process steps")
    return missing
  }

  fieldValue(name) {
    const field = this.element.querySelector(`[name='service[${name}]']`)
    return field ? field.value : ""
  }

  listValues(name) {
    return Array.from(this.element.querySelectorAll(`input[name='service[${name}][]']`))
      .map((input) => input.value.trim())
      .filter(Boolean)
  }

  bodyHasText(html) {
    if (!html || !html.trim()) return false
    const div = document.createElement("div")
    div.innerHTML = html
    return (div.textContent || "").trim().length > 0
  }

  slugify(value) {
    return value
      .toLowerCase()
      .trim()
      .replace(/[^a-z0-9\s-]/g, "")
      .replace(/\s+/g, "-")
      .replace(/-+/g, "-")
      .replace(/^-|-$/g, "")
  }
}