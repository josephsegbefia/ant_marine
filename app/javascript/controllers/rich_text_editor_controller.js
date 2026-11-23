import { Controller } from "@hotwired/stimulus"
import {
  ANT_RICH_TEXT_BLOCK_ATTRS,
  ANT_RICH_TEXT_HEADING_ATTRS,
  ANT_RICH_TEXT_INLINE_ATTRS
} from "trix_ant_marine_config"

export default class extends Controller {
  static targets = ["editor", "headingSelect", "morePanel"]

  connect() {
    this.element.addEventListener("trix-initialize", this.onInitialize)
    this.element.addEventListener("trix-file-accept", this.blockFileAttach)
    this.element.addEventListener("trix-attachment-add", this.blockAttachmentAdd)
    this.element.addEventListener("trix-selection-change", this.syncToolbarState)
    this.element.addEventListener("trix-update", this.syncToolbarState)
    this.closeMoreOnClickOutside = this.closeMoreOnClickOutside.bind(this)
    document.addEventListener("click", this.closeMoreOnClickOutside)
  }

  disconnect() {
    this.element.removeEventListener("trix-initialize", this.onInitialize)
    this.element.removeEventListener("trix-file-accept", this.blockFileAttach)
    this.element.removeEventListener("trix-attachment-add", this.blockAttachmentAdd)
    this.element.removeEventListener("trix-selection-change", this.syncToolbarState)
    this.element.removeEventListener("trix-update", this.syncToolbarState)
    document.removeEventListener("click", this.closeMoreOnClickOutside)
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
    ANT_RICH_TEXT_HEADING_ATTRS.forEach((attr) => editor.deactivateAttribute(attr))

    if (value !== "paragraph") {
      editor.activateAttribute(value)
    }

    this.editorElement.focus()
    this.syncToolbarState()
  }

  clearFormatting(event) {
    event.preventDefault()
    const editor = this.editorElement?.editor
    if (!editor) return

    const range = editor.getSelectedRange()
    if (!range || range[0] === range[1]) return

    editor.recordUndoEntry("Clear formatting")
    ANT_RICH_TEXT_INLINE_ATTRS.forEach((attr) => editor.deactivateAttribute(attr))
    ;["quote", "code", ...ANT_RICH_TEXT_HEADING_ATTRS].forEach((attr) => editor.deactivateAttribute(attr))

    while (editor.canDecreaseNestingLevel()) {
      editor.decreaseNestingLevel()
    }

    this.editorElement.focus()
    this.syncToolbarState()
    this.closeMore()
  }

  toggleMore(event) {
    event.preventDefault()
    event.stopPropagation()
    if (!this.hasMorePanelTarget) return
    const trigger = this.element.querySelector("[data-rich-text-editor-target='moreTrigger']")
    if (this.morePanelTarget.hasAttribute("hidden")) {
      this.morePanelTarget.removeAttribute("hidden")
      trigger?.setAttribute("aria-expanded", "true")
    } else {
      this.closeMore()
    }
  }

  closeMore() {
    if (this.hasMorePanelTarget) {
      this.morePanelTarget.setAttribute("hidden", "")
      this.element.querySelector("[data-rich-text-editor-target='moreTrigger']")?.setAttribute("aria-expanded", "false")
    }
  }

  closeMoreOnClickOutside(event) {
    if (!this.hasMorePanelTarget || this.morePanelTarget.hasAttribute("hidden")) return
    if (this.element.contains(event.target)) return
    this.closeMore()
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

    toolbar.querySelectorAll("[data-trix-action='increaseNestingLevel']").forEach((button) => {
      button.disabled = !editor.canIncreaseNestingLevel()
    })
    toolbar.querySelectorAll("[data-trix-action='decreaseNestingLevel']").forEach((button) => {
      button.disabled = !editor.canDecreaseNestingLevel()
    })

    if (this.hasHeadingSelectTarget) {
      let current = "paragraph"
      ANT_RICH_TEXT_HEADING_ATTRS.forEach((attr) => {
        if (editor.attributeIsActive(attr)) current = attr
      })
      if (this.headingSelectTarget.value !== current) {
        this.headingSelectTarget.value = current
      }
    }
  }
}