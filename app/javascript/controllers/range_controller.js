import { Controller } from "@hotwired/stimulus"

// Date-range presets for the Tally export.
export default class extends Controller {
  static targets = ["from", "to"]
  set(event) {
    this.fromTarget.value = event.currentTarget.dataset.from
    this.toTarget.value = event.currentTarget.dataset.to
  }
}
