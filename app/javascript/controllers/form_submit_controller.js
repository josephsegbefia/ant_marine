import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit"]
  static values = {
    loadingMessage: { type: String, default: "Sending..." }
  }

  connect() {
    this.busy = false
  }

  busy(event) {
    if (this.busy) return
    this.busy = true

    const submitters = this.submitTargets.length > 0
      ? this.submitTargets
      : Array.from(this.element.querySelectorAll("[type='submit'], button[data-disable-with]"))

    submitters.forEach((el) => {
      el.setAttribute("aria-busy", "true")
      el.disabled = true
    })

    const stack = document.querySelector("[data-controller~='toast-stack']")
    if (stack) {
      const controller = this.application.getControllerForElementAndIdentifier(stack, "toast-stack")
      controller?.showLoading(this.loadingMessageValue)
    }
  }

  idle() {
    this.busy = false
    const submitters = this.submitTargets.length > 0
      ? this.submitTargets
      : Array.from(this.element.querySelectorAll("[type='submit'], button[data-disable-with]"))

    submitters.forEach((el) => {
      el.removeAttribute("aria-busy")
      el.disabled = false
    })

    const container = document.querySelector("[data-toast-stack-target='container']")
    if (container) {
      container.querySelectorAll('[data-toast-type="loading"]').forEach((el) => el.remove())
    }
  }
}