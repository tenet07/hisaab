import { Controller } from "@hotwired/stimulus"

// Warms the offline cache with today's shop pages so a salesman can open them without signal.
export default class extends Controller {
  static targets = ["link"]
  connect() {
    if (!navigator.onLine || !("serviceWorker" in navigator)) return
    const urls = this.linkTargets.map(a => a.href).slice(0, 40)
    let i = 0
    const next = () => { if (i < urls.length) fetch(urls[i++], { credentials: "same-origin" }).finally(() => setTimeout(next, 150)) }
    setTimeout(next, 1500)
  }
}
