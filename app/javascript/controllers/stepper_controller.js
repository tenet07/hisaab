import { Controller } from "@hotwired/stimulus"

// − / + buttons around a number input, clamped to its min/max.
export default class extends Controller {
  static targets = ["input"]
  inc() { this.bump(1) }
  dec() { this.bump(-1) }
  bump(d) {
    const i = this.inputTarget
    const min = i.min === "" ? -Infinity : +i.min, max = i.max === "" ? Infinity : +i.max
    i.value = Math.min(max, Math.max(min, (parseInt(i.value) || 0) + d))
    i.dispatchEvent(new Event("input", { bubbles: true }))
  }
}
