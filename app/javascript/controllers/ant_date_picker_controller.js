import { Controller } from "@hotwired/stimulus"

const MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
const DISPLAY = new Intl.DateTimeFormat("en-GB", { weekday: "short", day: "numeric", month: "short", year: "numeric" })
const SPOKEN = new Intl.DateTimeFormat("en-GB", { weekday: "long", day: "numeric", month: "long", year: "numeric" })

// Dates are handled as local calendar days; ISO strings are parsed by hand to avoid time-zone shifts.
function parseIso(value) {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value || "")
  if (!match) return null
  const date = new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]))
  return date.getMonth() === Number(match[2]) - 1 ? date : null
}

function toIso(date) {
  const pad = (n) => String(n).padStart(2, "0")
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`
}

function sameDay(a, b) {
  return a && b && a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
}

function addDays(date, days) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate() + days)
}

// Moves by whole months, keeping the day where possible (31 Jan + 1 month = 28/29 Feb).
function addMonths(date, months) {
  const target = new Date(date.getFullYear(), date.getMonth() + months, 1)
  const lastDay = new Date(target.getFullYear(), target.getMonth() + 1, 0).getDate()
  return new Date(target.getFullYear(), target.getMonth(), Math.min(date.getDate(), lastDay))
}

function today() {
  const now = new Date()
  return new Date(now.getFullYear(), now.getMonth(), now.getDate())
}

// The ANT date picker: a trigger showing the chosen date and a calendar in a modal <dialog>.
// The original <input type="date"> keeps the submitted ISO value, so forms work unchanged.
export default class extends Controller {
  static targets = ["input", "label", "trigger", "display", "clear", "dialog", "month", "days", "today"]
  static values = {
    min: String,
    max: String,
    placeholder: String,
    rangeStartFor: String,
    rangeEndFor: String
  }

  connect() {
    this.inputTarget.type = "hidden"
    this.labelTarget.htmlFor = this.triggerTarget.id
    this.element.classList.add("is-enhanced")
    this.render()
  }

  disconnect() {
    if (this.dialogTarget.open) this.dialogTarget.close()
    this.inputTarget.type = "date"
    this.labelTarget.htmlFor = this.inputTarget.id
    this.element.classList.remove("is-enhanced")
  }

  get value() {
    return parseIso(this.inputTarget.value)
  }

  // Bounds include the paired field in a range (start can't pass the end, and the reverse).
  get bounds() {
    let min = parseIso(this.minValue)
    let max = parseIso(this.maxValue)
    const end = this.rangeStartForValue && parseIso(document.getElementById(this.rangeStartForValue)?.value)
    const start = this.rangeEndForValue && parseIso(document.getElementById(this.rangeEndForValue)?.value)
    if (end && (!max || end < max)) max = end
    if (start && (!min || start > min)) min = start
    return { min, max }
  }

  allowed(date) {
    const { min, max } = this.bounds
    return !(min && date < min) && !(max && date > max)
  }

  clamp(date) {
    const { min, max } = this.bounds
    if (min && date < min) return min
    if (max && date > max) return max
    return date
  }

  // ---- Trigger ---------------------------------------------------------------------------

  render() {
    const value = this.value
    this.displayTarget.textContent = value ? DISPLAY.format(value).replace(",", "") : this.placeholderValue
    this.displayTarget.classList.toggle("is-empty", !value)
    this.clearTarget.hidden = !value
  }

  open(event) {
    event?.preventDefault()
    this.focusDate = this.clamp(this.value || today())
    this.viewDate = new Date(this.focusDate.getFullYear(), this.focusDate.getMonth(), 1)
    this.direction = null
    this.todayTarget.hidden = !this.allowed(today())
    this.dialogTarget.showModal()
    this.drawMonth()
    this.focusCurrent()
  }

  clear(event) {
    event?.preventDefault()
    this.commit(null)
    this.triggerTarget.focus()
  }

  commit(date) {
    const iso = date ? toIso(date) : ""
    if (this.inputTarget.value === iso) {
      this.render()
      return
    }
    this.inputTarget.value = iso
    this.render()
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  // ---- Dialog ----------------------------------------------------------------------------

  cancel(event) {
    event?.preventDefault()
    this.dialogTarget.close()
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.dialogTarget.close()
  }

  closed() {
    this.triggerTarget.focus()
  }

  dialogKeydown(event) {
    // Escape is handled by the dialog itself; keep it from reaching a surrounding dialog.
    if (event.key === "Escape") event.stopPropagation()
  }

  selectToday(event) {
    event?.preventDefault()
    this.choose(today())
  }

  choose(date) {
    if (!this.allowed(date)) return
    this.commit(date)
    this.dialogTarget.close()
  }

  previousMonth() { this.shiftView(-1) }
  nextMonth() { this.shiftView(1) }
  previousYear() { this.shiftView(-12) }
  nextYear() { this.shiftView(12) }

  shiftView(months) {
    this.direction = months > 0 ? "next" : "previous"
    this.viewDate = new Date(this.viewDate.getFullYear(), this.viewDate.getMonth() + months, 1)
    this.focusDate = addMonths(this.focusDate, months)
    this.drawMonth()
  }

  // ---- Calendar grid ---------------------------------------------------------------------

  drawMonth() {
    const year = this.viewDate.getFullYear()
    const month = this.viewDate.getMonth()
    this.monthTarget.textContent = `${MONTHS[month]} ${year}`

    // Weeks start on Monday.
    const offset = (new Date(year, month, 1).getDay() + 6) % 7
    const start = addDays(new Date(year, month, 1), -offset)
    const selected = this.value
    const now = today()
    const rows = []

    for (let week = 0; week < 6; week++) {
      const row = document.createElement("tr")
      for (let day = 0; day < 7; day++) {
        const date = addDays(start, week * 7 + day)
        const cell = document.createElement("td")
        if (date.getMonth() !== month) {
          cell.className = "ant-date__outside"
          cell.setAttribute("aria-hidden", "true")
          cell.textContent = date.getDate()
        } else {
          cell.setAttribute("role", "gridcell")
          const button = document.createElement("button")
          button.type = "button"
          button.className = "ant-date__day"
          button.textContent = date.getDate()
          button.dataset.date = toIso(date)
          button.tabIndex = -1
          button.setAttribute("aria-label", SPOKEN.format(date).replace(",", ""))
          if (sameDay(date, now)) {
            button.classList.add("is-today")
            button.setAttribute("aria-current", "date")
          }
          if (sameDay(date, selected)) {
            button.classList.add("is-selected")
            cell.setAttribute("aria-selected", "true")
          }
          if (!this.allowed(date)) {
            button.setAttribute("aria-disabled", "true")
            button.classList.add("is-disabled")
          }
          button.addEventListener("click", () => this.choose(date))
          cell.appendChild(button)
        }
        row.appendChild(cell)
      }
      rows.push(row)
    }

    this.daysTarget.replaceChildren(...rows)
    this.daysTarget.classList.remove("is-from-next", "is-from-previous")
    if (this.direction) {
      void this.daysTarget.offsetWidth
      this.daysTarget.classList.add(this.direction === "next" ? "is-from-next" : "is-from-previous")
    }
    this.markFocusable()
  }

  markFocusable() {
    const iso = toIso(this.focusDate)
    this.daysTarget.querySelectorAll(".ant-date__day").forEach((button) => {
      button.tabIndex = button.dataset.date === iso ? 0 : -1
    })
  }

  focusCurrent() {
    this.daysTarget.querySelector(`[data-date="${toIso(this.focusDate)}"]`)?.focus()
  }

  moveFocus(date) {
    const changedMonth = date.getMonth() !== this.viewDate.getMonth() || date.getFullYear() !== this.viewDate.getFullYear()
    if (changedMonth) {
      this.direction = date > this.focusDate ? "next" : "previous"
      this.viewDate = new Date(date.getFullYear(), date.getMonth(), 1)
      this.focusDate = date
      this.drawMonth()
    } else {
      this.focusDate = date
      this.markFocusable()
    }
    this.focusCurrent()
  }

  gridKeydown(event) {
    const date = this.focusDate
    const weekday = (date.getDay() + 6) % 7
    let next = null
    switch (event.key) {
      case "ArrowLeft": next = addDays(date, -1); break
      case "ArrowRight": next = addDays(date, 1); break
      case "ArrowUp": next = addDays(date, -7); break
      case "ArrowDown": next = addDays(date, 7); break
      case "Home": next = addDays(date, -weekday); break
      case "End": next = addDays(date, 6 - weekday); break
      case "PageUp": next = addMonths(date, event.shiftKey ? -12 : -1); break
      case "PageDown": next = addMonths(date, event.shiftKey ? 12 : 1); break
      case "Enter":
      case " ":
        event.preventDefault()
        this.choose(date)
        return
      default:
        return
    }
    event.preventDefault()
    this.moveFocus(next)
  }
}
