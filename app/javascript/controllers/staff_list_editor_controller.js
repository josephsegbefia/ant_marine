import { Controller } from "@hotwired/stimulus"

// Adds, removes, and reorders list inputs for scope items and process steps.
export default class extends Controller {
  static targets = ["list", "item", "input"]
  static values = { fieldName: String, placeholder: String }

  add(event) {
    event.preventDefault()
  const row = this.buildRow("")
    this.listTarget.appendChild(row)
    const input = row.querySelector("input")
    input?.focus()
    this.dispatchChange()
  }

  remove(event) {
    event.preventDefault()
    const row = event.target.closest("[data-staff-list-editor-target='item']")
    if (!row) return
    if (this.itemTargets.length <= 1) {
      const input = row.querySelector("input")
      if (input) input.value = ""
      return
    }
    row.remove()
    this.dispatchChange()
  }

  moveUp(event) {
    event.preventDefault()
    const row = event.target.closest("[data-staff-list-editor-target='item']")
    const prev = row?.previousElementSibling
    if (row && prev) {
      this.listTarget.insertBefore(row, prev)
      this.dispatchChange()
    }
  }

  moveDown(event) {
    event.preventDefault()
    const row = event.target.closest("[data-staff-list-editor-target='item']")
    const next = row?.nextElementSibling
    if (row && next) {
      this.listTarget.insertBefore(next, row)
      this.dispatchChange()
    }
  }

  buildRow(value) {
    const li = document.createElement("li")
    li.className = "staff-list-editor__item"
    li.dataset.staffListEditorTarget = "item"
    li.innerHTML = `
      <input type="text" name="${this.fieldNameValue}" value="${this.escapeAttr(value)}" class="ant-control staff-list-editor__input" placeholder="${this.escapeAttr(this.placeholderValue)}" autocomplete="off" data-staff-list-editor-target="input" data-action="input->staff-list-editor#dispatchChange">
      <div class="staff-list-editor__actions">
        <button type="button" class="staff-list-editor__icon-btn" data-action="staff-list-editor#moveUp" aria-label="Move up">↑</button>
        <button type="button" class="staff-list-editor__icon-btn" data-action="staff-list-editor#moveDown" aria-label="Move down">↓</button>
        <button type="button" class="staff-list-editor__icon-btn staff-list-editor__icon-btn--danger" data-action="staff-list-editor#remove" aria-label="Remove">✕</button>
      </div>
    `
    return li
  }

  dispatchChange() {
    this.dispatch("changed", { bubbles: true })
  }

  escapeAttr(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll('"', "&quot;")
      .replaceAll("<", "&lt;")
  }
}