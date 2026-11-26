import { Controller } from "@hotwired/stimulus"

// Enhances a native <select> with the ANT dropdown. The native select stays in the form,
// keeps its own data-action/targets and receives a bubbling "change" when a choice is made.
// Without JavaScript the native select is shown as an ordinary field.
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
    this.onNativeChange = this.onNativeChange.bind(this)
    this.reposition = this.reposition.bind(this)
    this.onFilter = () => this.filterOptions()
    this.onSearchKeydown = this.onSearchKeydown.bind(this)
    this.open = false
    this.activeIndex = -1

    if (this.fallbackValue || !this.hasNativeTarget) {
      this.enableFallback()
      return
    }

    this.wrapperTarget.classList.remove("ant-select--fallback")
    this.wrapperTarget.classList.add("is-enhanced")
    this.nativeTarget.tabIndex = -1
    this.buildOptions()
    this.syncFromNative()
    document.addEventListener("click", this.outsideClick)
    this.triggerTarget.addEventListener("keydown", this.onKeydown)
    this.nativeTarget.addEventListener("change", this.onNativeChange)
    if (this.hasSearchTarget) {
      this.searchTarget.addEventListener("input", this.onFilter)
      this.searchTarget.addEventListener("keydown", this.onSearchKeydown)
    }
  }

  disconnect() {
    document.removeEventListener("click", this.outsideClick)
    if (this.hasTriggerTarget) this.triggerTarget.removeEventListener("keydown", this.onKeydown)
    if (this.hasNativeTarget) {
      this.nativeTarget.removeEventListener("change", this.onNativeChange)
      this.nativeTarget.removeAttribute("tabindex")
      this.wrapperTarget.classList.remove("is-enhanced")
    }
    if (this.hasSearchTarget) {
      this.searchTarget.removeEventListener("input", this.onFilter)
      this.searchTarget.removeEventListener("keydown", this.onSearchKeydown)
    }
    if (this.open) this.close()
  }

  enableFallback() {
    if (this.hasWrapperTarget) this.wrapperTarget.classList.add("ant-select--fallback")
    if (this.hasTriggerTarget) this.triggerTarget.hidden = true
    if (this.hasPanelTarget) this.panelTarget.hidden = true
  }

  get disabled() {
    return this.nativeTarget.matches(":disabled")
  }

  buildOptions() {
    this.listboxTarget.innerHTML = ""
    Array.from(this.nativeTarget.options).forEach((option, index) => {
      if (option.value === "" && option.text === "") return

      const item = document.createElement("li")
      item.className = "ant-select__option"
      item.id = `${this.nativeTarget.id}_opt_${index}`
      item.setAttribute("role", "option")
      item.dataset.value = option.value
      item.textContent = option.text
      item.tabIndex = -1
      if (option.disabled) item.setAttribute("aria-disabled", "true")
      item.addEventListener("click", (e) => {
        e.stopPropagation()
        this.chooseOption(item)
      })
      this.listboxTarget.appendChild(item)
    })
  }

  syncFromNative() {
    const selected = this.nativeTarget.selectedOptions[0]
    const empty = !selected || selected.value === ""
    this.valueTarget.textContent = selected?.text || this.placeholderValue
    this.valueTarget.classList.toggle("ant-select__value--placeholder", empty)
    this.triggerTarget.disabled = this.disabled

    this.listboxTarget.querySelectorAll('[role="option"]').forEach((el) => {
      el.setAttribute("aria-selected", el.dataset.value === this.nativeTarget.value ? "true" : "false")
    })
  }

  onNativeChange() {
    this.syncFromNative()
  }

  toggle(event) {
    event?.preventDefault()
    if (this.disabled) return
    this.open ? this.close() : this.openPanel()
  }

  openPanel() {
    this.open = true
    this.panelTarget.classList.remove("hidden")
    this.triggerTarget.setAttribute("aria-expanded", "true")
    if (this.element.closest("dialog")) {
      this.panelTarget.classList.add("ant-select__panel--floating")
      this.reposition()
      window.addEventListener("resize", this.reposition)
      this.element.closest("dialog").addEventListener("scroll", this.reposition, true)
    }
    const selectedIndex = this.visibleOptions().findIndex((o) => o.dataset.value === this.nativeTarget.value)
    this.activeIndex = Math.max(0, selectedIndex)
    this.highlightActive()
    if (this.hasSearchTarget) this.searchTarget.focus()
  }

  // Inside a scrolling <dialog> the panel is fixed to the viewport so it is never clipped.
  reposition() {
    const rect = this.triggerTarget.getBoundingClientRect()
    const panel = this.panelTarget
    const below = window.innerHeight - rect.bottom
    const height = Math.min(panel.scrollHeight, 240)
    panel.style.left = `${rect.left}px`
    panel.style.width = `${rect.width}px`
    if (below < height + 12 && rect.top > below) {
      panel.style.top = ""
      panel.style.bottom = `${window.innerHeight - rect.top + 4}px`
    } else {
      panel.style.bottom = ""
      panel.style.top = `${rect.bottom + 4}px`
    }
  }

  close() {
    this.open = false
    this.panelTarget.classList.add("hidden")
    this.triggerTarget.setAttribute("aria-expanded", "false")
    this.activeIndex = -1
    this.clearHighlight()
    if (this.panelTarget.classList.contains("ant-select__panel--floating")) {
      this.panelTarget.classList.remove("ant-select__panel--floating")
      this.panelTarget.removeAttribute("style")
      window.removeEventListener("resize", this.reposition)
      this.element.closest("dialog")?.removeEventListener("scroll", this.reposition, true)
    }
    if (this.hasSearchTarget && this.searchTarget.value) {
      this.searchTarget.value = ""
      this.filterOptions()
    }
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
        if (!this.open) this.openPanel()
        else this.selectActive()
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
        if (this.open) {
          // Keep Escape from also closing a surrounding dialog.
          event.preventDefault()
          event.stopPropagation()
          this.close()
          this.triggerTarget.focus()
        }
        break
      case "Tab":
        if (this.open) this.close()
        break
      default:
        break
    }
  }

  onSearchKeydown(event) {
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      this.move(event.key === "ArrowDown" ? 1 : -1)
    } else if (event.key === "Enter") {
      event.preventDefault()
      this.selectActive()
    } else if (event.key === "Escape") {
      event.preventDefault()
      event.stopPropagation()
      this.close()
      this.triggerTarget.focus()
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
  }

  highlightActive() {
    this.clearHighlight()
    const active = this.visibleOptions()[this.activeIndex]
    if (active) {
      active.classList.add("ant-select__option--active")
      active.scrollIntoView({ block: "nearest" })
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
    const active = this.visibleOptions()[this.activeIndex]
    if (active) this.chooseOption(active)
  }

  chooseOption(item) {
    if (item.getAttribute("aria-disabled") === "true") return
    const changed = this.nativeTarget.value !== item.dataset.value
    this.nativeTarget.value = item.dataset.value
    // Keep both change and input bubbling so Turbo/forms and Capybara helpers observe the update.
    if (changed) {
      this.nativeTarget.dispatchEvent(new Event("input", { bubbles: true }))
      this.nativeTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }
    this.syncFromNative()
    this.close()
    this.triggerTarget.focus()
  }

  filterOptions() {
    const term = this.searchTarget.value.toLowerCase()
    this.listboxTarget.querySelectorAll('[role="option"]').forEach((el) => {
      el.style.display = el.textContent.toLowerCase().includes(term) ? "" : "none"
    })
    this.activeIndex = 0
    this.highlightActive()
  }
}
