import { Controller } from "@hotwired/stimulus"
import { enqueue, formToObject } from "lib/outbox"

// A field-staff form that still works with no signal: offline (or if the request dies on the way)
// the entry is kept on the phone with its client_uuid and synced later — never posted twice.
export default class extends Controller {
  static targets = ["uuid", "photo", "photoLabel"]
  static values = { kind: String, back: String }

  connect() {
    this.onError = (e) => { if (e.target === this.element) this.saveOffline() }
    this.element.addEventListener("turbo:fetch-request-error", this.onError)
  }
  disconnect() { this.element.removeEventListener("turbo:fetch-request-error", this.onError) }

  submit(e) {
    if (navigator.onLine) return // normal Turbo submit
    e.preventDefault()
    this.saveOffline()
  }

  async photoPicked() {
    const file = this.photoTarget.files[0]
    if (!file) return
    this.photoData = await this.shrink(file)
    if (this.hasPhotoLabelTarget) this.photoLabelTarget.textContent = "Photo ready ✓"
  }

  async saveOffline() {
    if (this.saved) return
    this.saved = true
    const params = formToObject(new FormData(this.element))
    delete params.photo
    if (this.photoData) params.photo_data = this.photoData
    enqueue({ kind: this.kindValue, client_uuid: this.uuidTarget.value, params, saved_at: new Date().toISOString() })
    window.dispatchEvent(new Event("outbox:changed"))
    alert("No signal — saved on this phone. It will be sent automatically when you're back online.")
    window.location.href = this.backValue
  }

  // Downscale camera photos so they fit in phone storage and sync fast
  shrink(file) {
    return new Promise((resolve) => {
      const img = new Image()
      img.onload = () => {
        const s = Math.min(1, 1024 / Math.max(img.width, img.height))
        const c = document.createElement("canvas")
        c.width = img.width * s; c.height = img.height * s
        c.getContext("2d").drawImage(img, 0, 0, c.width, c.height)
        resolve(c.toDataURL("image/jpeg", 0.7))
      }
      img.src = URL.createObjectURL(file)
    })
  }
}
