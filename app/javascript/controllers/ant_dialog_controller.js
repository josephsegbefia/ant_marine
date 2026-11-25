import { Controller } from "@hotwired/stimulus"

// Opens a native <dialog> as a modal. The browser provides the focus trap and Escape to close;
// focus returns to the button that opened it.
export default class extends Controller {
  static targets = ["dialog"]

  open(event) {
    event?.preventDefault()
    this.opener = event?.currentTarget
    this.dialogTarget.showModal()
    const field = this.dialogTarget.querySelector("textarea, input:not([type=hidden]), select")
    if (field) field.focus()
  }

  close(event) {
    event?.preventDefault()
    this.dialogTarget.close()
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.dialogTarget.close()
  }

  restoreFocus() {
    this.opener?.focus()
  }
}
