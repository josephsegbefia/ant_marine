import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["option", "input"]

  select(event) {
    this.optionTargets.forEach((el) => el.classList.remove("ant-icon-picker__option--selected"))
    event.target.closest(".ant-icon-picker__option")?.classList.add("ant-icon-picker__option--selected")
  }

  navigate(event) {
    const options = this.optionTargets
    const current = options.indexOf(event.currentTarget)
    if (current < 0) return

    let next = current
    if (event.key === "ArrowRight" || event.key === "ArrowDown") next = (current + 1) % options.length
    if (event.key === "ArrowLeft" || event.key === "ArrowUp") next = (current - 1 + options.length) % options.length
    if (next !== current) {
      event.preventDefault()
      options[next].querySelector("input")?.focus()
    }
  }
}