import { Controller } from "@hotwired/stimulus"

// One-tap amounts: a button with data-value copies it into the input.
export default class extends Controller {
  static targets = ["input"]
  set(event) {
    this.inputTarget.value = event.currentTarget.dataset.value
    this.inputTarget.focus()
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
  }
}
