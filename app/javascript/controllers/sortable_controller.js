import { Controller } from "@hotwired/stimulus"

// Drag rows to set the drop order of a route; saves on drop.
export default class extends Controller {
  static targets = ["list"]
  static values = { url: String }

  grab(e) {
    const row = e.target.closest("tr")
    row.draggable = true
    row.addEventListener("dragend", () => { row.draggable = false; this.save() }, { once: true })
    this.listTarget.ondragover = (ev) => {
      ev.preventDefault()
      const over = ev.target.closest("tr")
      if (!over || over === row) return
      const r = over.getBoundingClientRect()
      over.parentNode.insertBefore(row, ev.clientY > r.top + r.height / 2 ? over.nextSibling : over)
    }
    row.ondragstart = (ev) => ev.dataTransfer.setData("text/plain", row.dataset.id)
  }

  save() {
    const ids = [...this.listTarget.querySelectorAll("tr[data-id]")].map(r => r.dataset.id).join(",")
    const token = document.querySelector("meta[name=csrf-token]").content
    fetch(this.urlValue, { method: "PATCH", headers: { "X-CSRF-Token": token, "Content-Type": "application/x-www-form-urlencoded" },
      body: `order=${ids}&dispatch_run[vehicle]=${encodeURIComponent(document.querySelector("#dispatch_run_vehicle")?.value || "")}` })
      .then(() => Turbo.visit(location.href, { action: "replace" }))
  }
}
