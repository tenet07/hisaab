import { Controller } from "@hotwired/stimulus"

// "Install app" button: shown only when the browser offers installing (Chrome/Edge on
// desktop and Android). On iPhone it explains Share -> Add to Home Screen instead.
let deferred = null
window.addEventListener("beforeinstallprompt", (e) => {
  e.preventDefault()
  deferred = e
  document.querySelectorAll("[data-controller~=install]").forEach((el) => el.hidden = false)
})

export default class extends Controller {
  static targets = ["ios"]

  connect() {
    const standalone = window.matchMedia("(display-mode: standalone)").matches || navigator.standalone
    if (standalone) return
    if (deferred) this.element.hidden = false
    const ios = /iphone|ipad|ipod/i.test(navigator.userAgent)
    if (ios && this.hasIosTarget) { this.element.hidden = false; this.iosTarget.hidden = false }
  }

  async install() {
    if (!deferred) return
    deferred.prompt()
    await deferred.userChoice
    deferred = null
    this.element.hidden = true
  }
}
