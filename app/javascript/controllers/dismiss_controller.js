import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { after: Number }
  connect() { if (this.afterValue) this.timer = setTimeout(() => this.close(), this.afterValue) }
  disconnect() { clearTimeout(this.timer) }
  close() { this.element.remove() }
}
