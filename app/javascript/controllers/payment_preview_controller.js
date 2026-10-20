import { Controller } from "@hotwired/stimulus"

// Shows the picked customer's unpaid bills so the cashier knows what the payment will clear.
export default class extends Controller {
  static targets = ["dues"]
  async load(e) {
    const res = await fetch(`/customers/${e.detail.id}?dues=1`, { headers: { Accept: "text/html" } })
    if (res.ok) this.duesTarget.innerHTML = await res.text()
  }
}
