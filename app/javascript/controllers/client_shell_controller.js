import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["nav", "toggle", "backdrop"]

  connect() {
    this.onEscape = (event) => {
      if (event.key === "Escape") this.close()
    }
  }

  disconnect() {
    this.unlockScroll()
    document.removeEventListener("keydown", this.onEscape)
  }

  toggle() {
    const expanded = this.navTarget.classList.toggle("client-app-side__nav--open")
    this.toggleTarget.setAttribute("aria-expanded", expanded ? "true" : "false")

    if (expanded) {
      this.showBackdrop()
      this.lockScroll()
      document.addEventListener("keydown", this.onEscape)
    } else {
      this.hideDrawer()
    }
  }

  close() {
    if (!this.navTarget.classList.contains("client-app-side__nav--open")) return

    this.navTarget.classList.remove("client-app-side__nav--open")
    this.toggleTarget.setAttribute("aria-expanded", "false")
    this.hideDrawer()
  }

  hideDrawer() {
    this.hideBackdrop()
    this.unlockScroll()
    document.removeEventListener("keydown", this.onEscape)
  }

  showBackdrop() {
    if (!this.hasBackdropTarget) return

    this.backdropTarget.hidden = false
  }

  hideBackdrop() {
    if (!this.hasBackdropTarget) return

    this.backdropTarget.hidden = true
  }

  lockScroll() {
    document.body.classList.add("client-shell-scroll-lock")
  }

  unlockScroll() {
    document.body.classList.remove("client-shell-scroll-lock")
  }
}