import { Controller } from "@hotwired/stimulus"

// Hand-over: reveal "why short?" only for items given short, and make the
// button say what will happen. The server still validates the code.
export default class extends Controller {
  static targets = ["row", "shortNote", "otp", "photo", "photoBox", "submit", "label"]

  connect() { this.check() }

  check() {
    let anyShort = false
    this.rowTargets.forEach((row) => {
      const billed = +row.dataset.billed
      const given = parseInt(row.querySelector("input[name^='delivered']").value) || 0
      const short = given < billed
      row.classList.toggle("short", short)
      row.querySelector("[data-short]").hidden = !short
      row.querySelector("input[name^='reasons']").required = short
      anyShort ||= short
    })
    this.shortNoteTarget.hidden = !anyShort
    this.labelTarget.textContent = anyShort ? "Partly delivered" : "Delivered"
  }

  proof() {
    this.otpTarget.value = this.otpTarget.value.replace(/\D/g, "").slice(0, 4)
  }

  submit(e) {
    const hasCode = this.otpTarget.value.length === 4
    const hasPhoto = this.photoTarget.files && this.photoTarget.files.length > 0
    if (!hasCode && !hasPhoto) {
      e.preventDefault()
      this.otpTarget.focus()
      this.otpTarget.setCustomValidity("Enter the 4-digit code, or take a photo below.")
      this.otpTarget.reportValidity()
      this.otpTarget.addEventListener("input", () => this.otpTarget.setCustomValidity(""), { once: true })
      return
    }
    this.submitTarget.disabled = true
    this.labelTarget.textContent = "Saving…"
  }
}
