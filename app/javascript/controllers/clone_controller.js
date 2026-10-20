import { Controller } from "@hotwired/stimulus"

// Copies the sidebar nav into the phone-width menu.
export default class extends Controller {
  static values = { source: String }
  connect() { const src = document.querySelector(this.sourceValue); if (src) this.element.innerHTML = src.innerHTML }
}
