import { Controller } from "@hotwired/stimulus"

const PREVIEW_ALLOWED_TAGS = new Set([
  "P", "BR", "UL", "OL", "LI", "STRONG", "EM", "A", "U", "DEL", "PRE", "CODE",
  "H1", "H2", "H3", "BLOCKQUOTE", "DIV"
])

export default class extends Controller {
  static targets = [
    "panel", "tab", "stepField", "errorSummary", "errorList", "titleField", "suggestedPath",
    "previewTitle", "previewSummary", "previewBody", "previewMeta", "previewUrl",
    "previewSeoTitle", "previewSeoDescription", "missingList", "missingPanel",
    "backButton", "saveContinueButton", "submitReviewBlock", "footerStepLabel", "footerStepName"
  ]

  static values = {
    step: { type: Number, default: 1 },
    stepCount: Number,
    paramPrefix: String,
    publicPathPrefix: String,
    stepLabels: Array,
    newRecord: Boolean,
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
      if (this.hasTitleFieldTarget && !this.titleFieldTarget.value.trim()) {
        event.preventDefault()
        this.showErrors(["Enter a title to save this draft."])
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
      panel.toggleAttribute("hidden", Number(panel.dataset.step) !== step)
    })
    this.tabTargets.forEach((tab) => {
      const tabStep = Number(tab.dataset.step)
      const selected = tabStep === step
      tab.setAttribute("aria-selected", selected ? "true" : "false")
      tab.classList.toggle("staff-editor-step__tab--current", selected)
      tab.classList.toggle("staff-editor-step__tab--complete", tabStep < step)
    })
    this.element.querySelector(`#editor-step-heading-${step}`)?.focus()
    this.syncFooter(step)
    this.refreshPreview()
  }

  syncFooter(step) {
    if (this.hasBackButtonTarget) this.backButtonTarget.hidden = step === 1
    if (this.hasSaveContinueButtonTarget) this.saveContinueButtonTarget.hidden = step >= this.stepCountValue
    if (this.hasSubmitReviewBlockTarget) this.submitReviewBlockTarget.hidden = step !== this.stepCountValue
    if (this.hasFooterStepLabelTarget) {
      this.footerStepLabelTarget.textContent = `Step ${step} of ${this.stepCountValue}`
    }
    if (this.hasFooterStepNameTarget) {
      this.footerStepNameTarget.textContent = this.stepLabelsValue[step - 1] || ""
    }
  }

  validateStep(step) {
    const panel = this.panelTargets.find((p) => Number(p.dataset.step) === step)
    const spec = (panel?.dataset.validate || "").split("|").filter(Boolean)
    const messages = []

    spec.forEach((entry) => {
      const [field, message] = entry.split(":")
      if (!field) return
      const rich = this.richTextValue(field)
      if (rich) {
        if (!this.bodyHasText(rich)) messages.push(message || "Complete this step before continuing.")
      } else if (!this.fieldValue(field).trim()) {
        messages.push(message || "Complete this step before continuing.")
      }
    })

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
    const panel = this.panelTargets.find((p) => Number(p.dataset.step) === this.stepValue)
    const first = (panel?.dataset.validate || "").split("|")[0]?.split(":")[0]
    if (first === "body") {
      this.element.querySelector("trix-editor")?.focus()
      return
    }
    const name = `${this.paramPrefixValue}[${first}]`
    this.element.querySelector(`[name='${name}']`)?.focus()
  }

  titleInput() {
    this.markDirty()
    if (!this.hasSuggestedPathTarget || !this.newRecordValue || !this.publicPathPrefixValue) return
    const slug = this.slugify(this.titleFieldTarget.value)
    this.suggestedPathTarget.textContent = slug
      ? `Likely address after save: ${this.publicPathPrefixValue}${slug}`
      : "We will assign an address when you save this draft."
  }

  refreshPreview() {
    const title = this.hasTitleFieldTarget ? this.titleFieldTarget.value.trim() : this.fieldValue("title")
    if (this.hasPreviewTitleTarget) {
      this.previewTitleTarget.textContent = title || "Title preview"
    }
    if (this.hasPreviewSummaryTarget) {
      this.previewSummaryTarget.textContent = this.fieldValue("summary") || "Short introduction will appear here."
    }
    if (this.hasPreviewBodyTarget) {
      const bodyHtml = this.richTextValue("body")
      if (bodyHtml.trim() && this.bodyHasText(bodyHtml)) {
        this.previewBodyTarget.classList.add("public-rich-text")
        this.previewBodyTarget.innerHTML = this.sanitizePreviewHtml(bodyHtml)
      } else {
        this.previewBodyTarget.classList.remove("public-rich-text")
        this.previewBodyTarget.textContent = "Main content will appear here."
      }
    }
    if (this.hasPreviewMetaTarget) {
      this.previewMetaTarget.textContent = this.fieldValue("category") || this.fieldValue("service_category") || ""
    }
    if (this.hasPreviewUrlTarget) {
      const slug = this.savedSlugValue || this.slugify(title)
      if (this.publicPathPrefixValue && slug) {
        this.previewUrlTarget.textContent = `${this.publicPathPrefixValue}${slug}`
      } else if (this.element.dataset.fixedPagePath) {
        this.previewUrlTarget.textContent = this.element.dataset.fixedPagePath
      } else {
        this.previewUrlTarget.textContent = "Page address is assigned when you save"
      }
    }
    if (this.hasPreviewSeoTitleTarget) {
      this.previewSeoTitleTarget.textContent = this.fieldValue("seo_title") || title || "Page title for search"
    }
    if (this.hasPreviewSeoDescriptionTarget) {
      this.previewSeoDescriptionTarget.textContent =
        this.fieldValue("seo_description") || this.fieldValue("summary") || "Search description preview"
    }
    if (this.hasMissingListTarget) {
      this.missingListTarget.replaceChildren()
      const missing = this.computeMissing()
      missing.forEach((label) => {
        const li = document.createElement("li")
        li.textContent = label
        this.missingListTarget.appendChild(li)
      })
      if (this.hasMissingPanelTarget) this.missingPanelTarget.toggleAttribute("hidden", missing.length === 0)
    }
  }

  computeMissing() {
    const missing = []
    if (this.hasTitleFieldTarget && !this.titleFieldTarget.value.trim()) missing.push("Title")
    if (!this.fieldValue("summary").trim()) missing.push("Short introduction")
    if (!this.bodyHasText(this.richTextValue("body"))) missing.push("Main content")
    return missing
  }

  fieldValue(name) {
    const field = this.element.querySelector(`[name='${this.paramPrefixValue}[${name}]']`)
    return field ? field.value : ""
  }

  richTextValue(name) {
    const hidden = this.element.querySelector(`input[name='${this.paramPrefixValue}[${name}]']`)
    return hidden ? hidden.value : ""
  }

  bodyHasText(html) {
    if (!html || !html.trim()) return false
    const div = document.createElement("div")
    div.innerHTML = this.sanitizePreviewHtml(html)
    return (div.textContent || "").trim().length > 0
  }

  sanitizePreviewHtml(html) {
    const template = document.createElement("template")
    template.innerHTML = html
    const walk = (node) => {
      Array.from(node.childNodes).forEach((child) => {
        if (child.nodeType === Node.ELEMENT_NODE) {
          const el = child
          if (!PREVIEW_ALLOWED_TAGS.has(el.tagName)) {
            el.replaceWith(...el.childNodes)
            return
          }
          if (el.tagName === "A") {
            const href = (el.getAttribute("href") || "").trim().toLowerCase()
            if (href.startsWith("javascript:")) el.setAttribute("href", "#")
          }
          [...el.attributes].forEach((attr) => {
            if (attr.name.startsWith("on")) el.removeAttribute(attr.name)
          })
        }
        walk(child)
      })
    }
    walk(template.content)
    return template.innerHTML
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