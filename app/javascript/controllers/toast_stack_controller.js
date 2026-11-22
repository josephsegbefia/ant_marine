import { Controller } from "@hotwired/stimulus"

const DISMISS_MS = {
  success: 5000,
  info: 5000,
  warning: 8000,
  error: 12000,
  loading: 0,
  pending: 0
}

export default class extends Controller {
  static targets = ["container"]
  static values = {
    flash: { type: Array, default: [] }
  }

  connect() {
    this.pausedToasts = new Set()
    this.shownKeys = new Set()
    this.beforeCache = this.beforeCache.bind(this)
    document.addEventListener("turbo:before-cache", this.beforeCache)

    this.flashValue.forEach((message) => this.show(message))
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.beforeCache)
  }

  beforeCache() {
    if (this.hasContainerTarget) this.containerTarget.innerHTML = ""
  }

  show(config) {
    const key = `${config.type}:${config.message}`
    if (this.shownKeys.has(key)) return
    this.shownKeys.add(key)

    const toast = document.createElement("div")
    const assertive = config.assertive || config.type === "error"
    toast.className = `ant-toast ant-toast--${config.type}`
    toast.setAttribute("role", assertive ? "alert" : "status")
    if (assertive) this.containerTarget.setAttribute("aria-live", "assertive")
    toast.dataset.toastType = config.type

    const body = document.createElement("div")
    body.className = "ant-toast__body"
    if (config.title) {
      const title = document.createElement("div")
      title.className = "ant-toast__title"
      title.textContent = config.title
      body.appendChild(title)
    }
    const message = document.createElement("div")
    message.className = "ant-toast__message"
    message.textContent = config.message
    body.appendChild(message)

    if (config.action_label && config.action_href) {
      const actions = document.createElement("div")
      actions.className = "ant-toast__actions"
      const link = document.createElement("a")
      link.className = "ant-toast__action"
      link.href = config.action_href
      link.textContent = config.action_label
      actions.appendChild(link)
      body.appendChild(actions)
    }

    const dismiss = document.createElement("button")
    dismiss.type = "button"
    dismiss.className = "ant-toast__dismiss"
    dismiss.setAttribute("aria-label", "Dismiss notification")
    dismiss.textContent = "×"
    dismiss.addEventListener("click", () => this.removeToast(toast))

    toast.appendChild(body)
    toast.appendChild(dismiss)
    this.containerTarget.appendChild(toast)

    toast.addEventListener("mouseenter", () => this.pausedToasts.add(toast))
    toast.addEventListener("mouseleave", () => this.pausedToasts.delete(toast))
    toast.addEventListener("focusin", () => this.pausedToasts.add(toast))
    toast.addEventListener("focusout", () => this.pausedToasts.delete(toast))

    const ms = DISMISS_MS[config.type] ?? 6000
    if (ms > 0) this.scheduleDismiss(toast, ms)

    return toast
  }

  scheduleDismiss(toast, ms) {
    window.setTimeout(() => {
      if (this.pausedToasts.has(toast)) {
        this.scheduleDismiss(toast, ms)
        return
      }
      this.removeToast(toast)
    }, ms)
  }

  removeToast(toast) {
    toast.remove()
    if (this.containerTarget.children.length === 0) {
      this.containerTarget.setAttribute("aria-live", "polite")
    }
  }

  showLoading(message) {
    return this.show({ type: "loading", title: "Please wait", message })
  }
}