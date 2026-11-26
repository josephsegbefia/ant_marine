import { Controller } from "@hotwired/stimulus"

// Client workspace shell: mobile drawer must never intercept clicks when closed.
export default class extends Controller {
  static targets = ["nav", "toggle", "backdrop"]

  connect() {
    this.onEscape = (event) => {
      if (event.key === "Escape") this.close()
    }
    // Close before Turbo navigates or caches — do NOT listen to turbo:load,
    // which can race a user opening the menu right after a navigation settles.
    this.onBeforeVisit = () => this.close()
    this.onBeforeCache = () => this.close()
    this.syncClosedState()
    document.addEventListener("turbo:before-visit", this.onBeforeVisit)
    document.addEventListener("turbo:before-cache", this.onBeforeCache)
  }

  disconnect() {
    this.unlockScroll()
    document.removeEventListener("keydown", this.onEscape)
    document.removeEventListener("turbo:before-visit", this.onBeforeVisit)
    document.removeEventListener("turbo:before-cache", this.onBeforeCache)
  }

  toggle() {
    const expanded = this.navTarget.classList.toggle("client-app-side__nav--open")
    this.toggleTarget.setAttribute("aria-expanded", expanded ? "true" : "false")

    if (expanded) {
      this.showBackdrop()
      this.lockScroll()
      this.clearInert()
      document.addEventListener("keydown", this.onEscape)
      this.toggleTarget.focus()
    } else {
      this.hideDrawer()
    }
  }

  close() {
    if (!this.navTarget.classList.contains("client-app-side__nav--open")) {
      this.syncClosedState()
      return
    }

    this.navTarget.classList.remove("client-app-side__nav--open")
    this.toggleTarget.setAttribute("aria-expanded", "false")
    this.hideDrawer()
  }

  hideDrawer() {
    this.hideBackdrop()
    this.unlockScroll()
    this.applyInert()
    document.removeEventListener("keydown", this.onEscape)
  }

  syncClosedState() {
    this.navTarget.classList.remove("client-app-side__nav--open")
    if (this.hasToggleTarget) this.toggleTarget.setAttribute("aria-expanded", "false")
    this.hideBackdrop()
    this.unlockScroll()
    this.applyInert()
  }

  applyInert() {
    // On small screens the closed drawer is display:none; still mark inert so
    // restored Turbo cache / focus cannot leave an interactive overlay.
    if (window.matchMedia("(min-width: 1024px)").matches) {
      this.clearInert()
      return
    }
    this.navTarget.setAttribute("inert", "")
    this.navTarget.setAttribute("aria-hidden", "true")
  }

  clearInert() {
    this.navTarget.removeAttribute("inert")
    this.navTarget.removeAttribute("aria-hidden")
  }

  showBackdrop() {
    if (!this.hasBackdropTarget) return

    this.backdropTarget.hidden = false
    this.backdropTarget.setAttribute("aria-hidden", "false")
  }

  hideBackdrop() {
    if (!this.hasBackdropTarget) return

    this.backdropTarget.hidden = true
    this.backdropTarget.setAttribute("aria-hidden", "true")
  }

  lockScroll() {
    document.body.classList.add("client-shell-scroll-lock")
  }

  unlockScroll() {
    document.body.classList.remove("client-shell-scroll-lock")
  }
}
