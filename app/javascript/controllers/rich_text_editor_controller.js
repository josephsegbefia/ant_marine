import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["editor"]

  connect() {
    this.element.addEventListener("trix-initialize", this.configureToolbar)
    this.element.addEventListener("trix-file-accept", this.blockFileAttach)
    this.element.addEventListener("trix-attachment-add", this.blockAttachmentAdd)
  }

  disconnect() {
    this.element.removeEventListener("trix-initialize", this.configureToolbar)
    this.element.removeEventListener("trix-file-accept", this.blockFileAttach)
    this.element.removeEventListener("trix-attachment-add", this.blockAttachmentAdd)
  }

  configureToolbar = (event) => {
    const toolbar = event.target.toolbarElement
  if (!toolbar) return

    toolbar.querySelector('[data-trix-button-group="file-tools"]')?.remove()
    toolbar.querySelector('[data-trix-button="attachFiles"]')?.remove()
  }

  blockFileAttach = (event) => {
    event.preventDefault()
  }

  blockAttachmentAdd = (event) => {
    event.preventDefault()
    event.attachment?.remove?.()
  }
}