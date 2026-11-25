import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["track", "slide", "dot", "status", "toggle"]
  static values = { interval: { type: Number, default: 7000 }, noun: { type: String, default: "Item" } }

  connect() {
    this.index = 0
    this.hovering = false
    this.focused = false
    this.onScreen = true
    this.reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.stopped = this.reduceMotion

    this.onVisibility = () => this.schedule()
    document.addEventListener("visibilitychange", this.onVisibility)

    if ("IntersectionObserver" in window) {
      this.observer = new IntersectionObserver(([entry]) => {
        this.onScreen = entry.isIntersecting
        this.schedule()
      }, { threshold: 0.35 })
      this.observer.observe(this.element)
    }

    this.element.classList.add("public-card-carousel--ready")
    this.render()
    this.schedule()
  }

  disconnect() {
    this.clearTimer()
    clearTimeout(this.settleTimer)
    document.removeEventListener("visibilitychange", this.onVisibility)
    this.observer?.disconnect()
    cancelAnimationFrame(this.syncFrame)
  }

  previous() {
    this.goTo(this.index - 1)
  }

  next() {
    this.goTo(this.index + 1)
  }

  show(event) {
    this.goTo(event.params.index)
  }

  toggle() {
    this.stopped = !this.stopped
    this.render()
    this.schedule()
  }

  hold(event) {
    if (event.type === "mouseenter") this.hovering = true
    if (event.type === "focusin") this.focused = true
    this.schedule()
  }

  release(event) {
    if (event.type === "mouseleave") this.hovering = false
    if (event.type === "focusout" && !this.element.contains(event.relatedTarget)) this.focused = false
    this.schedule()
  }

  sync() {
    cancelAnimationFrame(this.syncFrame)
    this.syncFrame = requestAnimationFrame(() => {
      const left = this.trackTarget.scrollLeft
      if (this.scrollingTo !== undefined) {
        if (Math.abs(left - this.scrollingTo) > 2) return
        this.scrollingTo = undefined
      }
      let nearest = 0
      this.slideTargets.forEach((_slide, i) => {
        if (Math.abs(this.slideLeft(i) - left) < Math.abs(this.slideLeft(nearest) - left)) nearest = i
      })
      if (nearest !== this.index) {
        this.index = nearest
        this.render()
        this.schedule()
      }
    })
  }

  goTo(target) {
    const count = this.slideTargets.length
    this.index = (target + count) % count
    this.scrollingTo = this.slideLeft(this.index)
    this.trackTarget.scrollTo({
      left: this.scrollingTo,
      behavior: this.reduceMotion ? "auto" : "smooth"
    })
    clearTimeout(this.settleTimer)
    this.settleTimer = setTimeout(() => { this.scrollingTo = undefined }, 1000)
    this.render()
    this.schedule()
  }

  slideLeft(i) {
    const left = this.slideTargets[i].offsetLeft - this.slideTargets[0].offsetLeft
    return Math.min(left, this.trackTarget.scrollWidth - this.trackTarget.clientWidth)
  }

  render() {
    const count = this.slideTargets.length
    this.slideTargets.forEach((slide, i) => {
      slide.inert = i !== this.index
    })
    this.dotTargets.forEach((dot, i) => {
      dot.setAttribute("aria-current", i === this.index ? "true" : "false")
    })
    if (this.hasStatusTarget) this.statusTarget.textContent = `${this.nounValue} ${this.index + 1} of ${count}`
    this.element.classList.toggle("public-card-carousel--stopped", this.stopped)
    if (this.hasToggleTarget) {
      this.toggleTarget.setAttribute("aria-label", this.stopped ? "Start automatic scrolling" : "Pause automatic scrolling")
    }
  }

  schedule() {
    this.clearTimer()
    if (this.stopped || this.hovering || this.focused || !this.onScreen || document.hidden) return
    this.timer = setTimeout(() => this.goTo(this.index + 1), this.intervalValue)
  }

  clearTimer() {
    if (this.timer) clearTimeout(this.timer)
    this.timer = null
  }
}
