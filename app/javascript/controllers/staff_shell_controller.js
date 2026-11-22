import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["nav", "toggle"]

  toggle() {
    const expanded = this.navTarget.classList.toggle("staff-app-side__nav--open")
    this.toggleTarget.setAttribute("aria-expanded", expanded ? "true" : "false")
  }
}