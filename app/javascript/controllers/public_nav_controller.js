import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["nav", "toggle"]

  connect() {
    this.onEscape = (event) => {
      if (event.key === "Escape") this.close()
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.onEscape)
    document.body.classList.remove("public-nav-scroll-lock")
  }

  toggle() {
    const expanded = this.navTarget.classList.toggle("public-header__nav--open")
    this.toggleTarget.setAttribute("aria-expanded", expanded ? "true" : "false")

    if (expanded) {
      document.addEventListener("keydown", this.onEscape)
      document.body.classList.add("public-nav-scroll-lock")
    } else {
      this.close()
    }
  }

  close() {
    this.navTarget.classList.remove("public-header__nav--open")
    this.toggleTarget.setAttribute("aria-expanded", "false")
    document.removeEventListener("keydown", this.onEscape)
    document.body.classList.remove("public-nav-scroll-lock")
  }
}