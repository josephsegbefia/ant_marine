import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["previewTitle", "previewSummary", "previewBody", "richField"]

  connect() {
    this.element.addEventListener("input", () => this.refresh())
    this.element.addEventListener("trix-change", () => this.refresh())
    this.refresh()
  }

  refresh() {
    const title = this.inputValue("title")
    const summary = this.textareaValue("summary")
    const bodyHtml = this.bodyHtml()

    if (this.hasPreviewTitleTarget) {
      this.previewTitleTarget.textContent = title || "Title preview"
    }
    if (this.hasPreviewSummaryTarget) {
      this.previewSummaryTarget.textContent = summary || "Short introduction will appear here."
    }
    if (this.hasPreviewBodyTarget) {
      if (bodyHtml.trim()) {
        this.previewBodyTarget.classList.add("public-rich-text")
        this.previewBodyTarget.innerHTML = bodyHtml
      } else {
        this.previewBodyTarget.classList.remove("public-rich-text")
        this.previewBodyTarget.textContent = "Main content will appear here with headings, lists and links."
      }
    }
  }

  inputValue(name) {
    const field = this.element.querySelector(`[name$='[${name}]']`)
    return field ? field.value.trim() : ""
  }

  textareaValue(name) {
    return this.inputValue(name)
  }

  bodyHtml() {
    const hidden = this.element.querySelector("input[name$='[body]']")
    if (hidden) return hidden.value

    const editor = this.element.querySelector("trix-editor")
    return editor ? editor.editor?.getDocument()?.toString() || "" : ""
  }
}