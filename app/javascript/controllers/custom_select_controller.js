import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["native", "wrapper", "trigger", "value", "panel", "listbox", "search"]
  static values = {
    searchable: Boolean,
    placeholder: String,
    fallback: Boolean
  }

  connect() {
    this.outsideClick = this.outsideClick.bind(this)
    this.onKeydown = this.onKeydown.bind(this)
    this.open = false
    this.activeIndex = -1

    if (this.fallbackValue || !this.hasNativeTarget) {
      this.enableFallback()
      return
    }

    this.buildOptions()
    this.syncFromNative()
    document.addEventListener("click", this.outsideClick)
    this.triggerTarget.addEventListener("keydown", this.onKeydown)
    if (this.hasSearchTarget) {
      this.searchTarget.addEventListener("input", () => this.filterOptions())
      this.searchTarget.addEventListener("keydown", (e) => this.onSearchKeydown(e))
    }
  }

  disconnect() {
    document.removeEventListener("click", this.outsideClick)
    if (this.hasTriggerTarget) {
      this.triggerTarget.removeEventListener("keydown", this.onKeydown)
    }
    if (this.hasNativeTarget) {
      this.nativeTarget.classList.remove("ant-select__native--hidden")
      this.wrapperTarget.classList.add("ant-select--fallback")
    }
    this.close()
  }

  enableFallback() {
    if (this.hasWrapperTarget) this.wrapperTarget.classList.add("ant-select--fallback")
    if (this.hasTriggerTarget) this.triggerTarget.hidden = true
    if (this.hasPanelTarget) this.panelTarget.hidden = true
  }

  buildOptions() {
    this.listboxTarget.innerHTML = ""
    Array.from(this.nativeTarget.options).forEach((option, index) => {
      if (option.value === "" && option.text === "") return

      const item = document.createElement("li")
      item.className = "ant-select__option"
      item.id = `${this.nativeTarget.id}_opt_${index}`
      item.role = "option"
      item.dataset.value = option.value
      item.textContent = option.text
      item.tabIndex = -1
      if (option.disabled) {
        item.setAttribute("aria-disabled", "true")
      }
      item.addEventListener("click", (e) => {
        e.stopPropagation()
        this.chooseOption(item)
      })
      this.listboxTarget.appendChild(item)
    })
  }

  syncFromNative() {
    const selected = this.nativeTarget.selectedOptions[0]
  const label = selected?.text || this.placeholderValue
    const empty = !selected || selected.value === ""
    this.valueTarget.textContent = label
    this.valueTarget.classList.toggle("ant-select__value--placeholder", empty)

    this.listboxTarget.querySelectorAll('[role="option"]').forEach((el) => {
      el.setAttribute("aria-selected", el.dataset.value === this.nativeTarget.value ? "true" : "false")
    })
  }

  toggle(event) {
    event?.preventDefault()
    if (this.nativeTarget.disabled) return
    this.open ? this.close() : this.openPanel()
  }

  openPanel() {
    this.open = true
    this.panelTarget.classList.remove("hidden")
    this.triggerTarget.setAttribute("aria-expanded", "true")
    const selectedIndex = Array.from(this.nativeTarget.options).findIndex((o) => o.value === this.nativeTarget.value)
    this.activeIndex = Math.max(0, selectedIndex)
    this.highlightActive()
    if (this.hasSearchTarget) this.searchTarget.focus()
  }

  close() {
    this.open = false
    this.panelTarget.classList.add("hidden")
    this.triggerTarget.setAttribute("aria-expanded", "false")
    this.activeIndex = -1
    this.clearHighlight()
  }

  outsideClick(event) {
    if (!this.open) return
    if (this.element.contains(event.target)) return
    this.close()
  }

  onKeydown(event) {
    switch (event.key) {
      case "Enter":
      case " ":
        event.preventDefault()
        if (!this.open) {
          this.openPanel()
        } else {
          this.selectActive()
        }
        break
      case "ArrowDown":
        event.preventDefault()
        if (!this.open) this.openPanel()
        else this.move(1)
        break
      case "ArrowUp":
        event.preventDefault()
        if (!this.open) this.openPanel()
        else this.move(-1)
        break
      case "Home":
        if (this.open) {
          event.preventDefault()
          this.activeIndex = 0
          this.highlightActive()
        }
        break
      case "End":
        if (this.open) {
          event.preventDefault()
          this.activeIndex = this.visibleOptions().length - 1
          this.highlightActive()
        }
        break
      case "Escape":
        event.preventDefault()
        this.close()
        this.triggerTarget.focus()
        break
      default:
        break
    }
  }

  onSearchKeydown(event) {
    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.activeIndex = 0
      this.highlightActive()
      this.visibleOptions()[0]?.focus()
    }
  }

  visibleOptions() {
    return Array.from(this.listboxTarget.querySelectorAll('[role="option"]')).filter((el) => el.style.display !== "none")
  }

  move(delta) {
    const options = this.visibleOptions()
    if (options.length === 0) return
    this.activeIndex = Math.min(options.length - 1, Math.max(0, this.activeIndex + delta))
    this.highlightActive()
    options[this.activeIndex]?.scrollIntoView({ block: "nearest" })
  }

  highlightActive() {
    this.clearHighlight()
    const options = this.visibleOptions()
    const active = options[this.activeIndex]
    if (active) {
      active.classList.add("ant-select__option--active")
      this.triggerTarget.setAttribute("aria-activedescendant", active.id)
    }
  }

  clearHighlight() {
    this.listboxTarget.querySelectorAll(".ant-select__option--active").forEach((el) => {
      el.classList.remove("ant-select__option--active")
    })
    this.triggerTarget.removeAttribute("aria-activedescendant")
  }

  selectActive() {
    const options = this.visibleOptions()
    const active = options[this.activeIndex]
    if (active) this.chooseOption(active)
  }

  chooseOption(item) {
    if (item.getAttribute("aria-disabled") === "true") return
    this.nativeTarget.value = item.dataset.value
    this.nativeTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.syncFromNative()
    this.close()
    this.triggerTarget.focus()
  }

  filterOptions() {
    const term = this.searchTarget.value.toLowerCase()
    this.listboxTarget.querySelectorAll('[role="option"]').forEach((el) => {
      const match = el.textContent.toLowerCase().includes(term)
      el.style.display = match ? "" : "none"
    })
    this.activeIndex = 0
    this.highlightActive()
  }
}