import { Controller } from "@hotwired/stimulus"
import Trix from "trix"

const HEADING_ATTRS = ["heading1", "heading2", "heading3"]

if (!Trix.config.blockAttributes.heading3) {
  Trix.config.blockAttributes.heading3 = {
    tagName: "h3",
    terminal: true,
    breakOnReturn: true,
    group: false
  }
}

export default class extends Controller {
  static targets = ["editor", "headingSelect"]

  connect() {
    this.element.addEventListener("trix-initialize", this.onInitialize)
    this.element.addEventListener("trix-file-accept", this.blockFileAttach)
    this.element.addEventListener("trix-attachment-add", this.blockAttachmentAdd)
    this.element.addEventListener("trix-selection-change", this.syncToolbarState)
    this.element.addEventListener("trix-update", this.syncToolbarState)
  }

  disconnect() {
    this.element.removeEventListener("trix-initialize", this.onInitialize)
    this.element.removeEventListener("trix-file-accept", this.blockFileAttach)
    this.element.removeEventListener("trix-attachment-add", this.blockAttachmentAdd)
    this.element.removeEventListener("trix-selection-change", this.syncToolbarState)
    this.element.removeEventListener("trix-update", this.syncToolbarState)
  }

  onInitialize = (event) => {
    this.editorElement = event.target
    this.toolbarElement = this.element.querySelector("trix-toolbar")
    this.toolbarElement?.querySelector('[data-trix-button-group="file-tools"]')?.remove()
    this.syncToolbarState()
  }

  blockFileAttach = (event) => {
    event.preventDefault()
  }

  blockAttachmentAdd = (event) => {
    event.preventDefault()
    event.attachment?.remove?.()
  }

  setHeading(event) {
    const editor = this.editorElement?.editor
    if (!editor) return

    const value = event.target.value
    HEADING_ATTRS.forEach((attr) => editor.deactivateAttribute(attr))

    if (value !== "paragraph") {
      editor.activateAttribute(value)
    }

    this.editorElement.focus()
    this.syncToolbarState()
  }

  syncToolbarState = () => {
    const editor = this.editorElement?.editor
    const toolbar = this.toolbarElement
    if (!editor || !toolbar) return

    toolbar.querySelectorAll("[data-trix-attribute]").forEach((button) => {
      const attribute = button.getAttribute("data-trix-attribute")
      if (!attribute) return
      const active = editor.attributeIsActive(attribute)
      button.classList.toggle("ant-rich-text-toolbar__btn--active", active)
      button.setAttribute("aria-pressed", active ? "true" : "false")
    })

    if (this.hasHeadingSelectTarget) {
      let current = "paragraph"
      HEADING_ATTRS.forEach((attr) => {
        if (editor.attributeIsActive(attr)) current = attr
      })
      if (this.headingSelectTarget.value !== current) {
        this.headingSelectTarget.value = current
      }
    }
  }
}