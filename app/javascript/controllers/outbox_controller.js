import { Controller } from "@hotwired/stimulus"
import { pending, remove } from "lib/outbox"

// Sends whatever field staff saved without signal, as soon as there is signal.
export default class extends Controller {
  static targets = ["badge", "offline"]
  static values = { syncUrl: String }

  connect() {
    this.onOnline = () => { this.status(); this.flush() }
    this.onOffline = () => this.status()
    window.addEventListener("online", this.onOnline)
    window.addEventListener("offline", this.onOffline)
    window.addEventListener("outbox:changed", this.onOnline)
    this.timer = setInterval(() => this.flush(), 30000)
    this.status()
    this.flush()
  }

  disconnect() {
    window.removeEventListener("online", this.onOnline)
    window.removeEventListener("offline", this.onOffline)
    window.removeEventListener("outbox:changed", this.onOnline)
    clearInterval(this.timer)
  }

  status() {
    const n = pending().length
    if (this.hasBadgeTarget) { this.badgeTarget.hidden = n === 0; this.badgeTarget.textContent = `${n} to sync` }
    if (this.hasOfflineTarget) this.offlineTarget.hidden = navigator.onLine
  }

  async flush() {
    const items = pending()
    if (!items.length || !navigator.onLine || this.busy) return
    this.busy = true
    try {
      const token = document.querySelector("meta[name=csrf-token]")?.content
      const res = await fetch(this.syncUrlValue, {
        method: "POST", credentials: "same-origin",
        headers: { "Content-Type": "application/json", Accept: "application/json", "X-CSRF-Token": token },
        body: JSON.stringify({ items })
      })
      if (!res.ok) return
      const { results } = await res.json()
      const failed = []
      results.forEach(r => {
        if (r.ok || r.permanent) remove(r.client_uuid)
        if (!r.ok) failed.push(r.error)
      })
      const synced = results.filter(r => r.ok).length
      if (synced) this.toast(`${synced} saved entr${synced === 1 ? "y" : "ies"} synced ✓`)
      if (failed.length) this.toast(`Couldn't sync: ${failed.join("; ")}`, true)
    } catch (_) { /* still offline */ } finally { this.busy = false; this.status() }
  }

  toast(msg, bad = false) {
    const el = document.createElement("div")
    el.className = `fixed top-20 left-1/2 z-50 -translate-x-1/2 rounded-xl px-4 py-2.5 text-sm shadow-lg ${bad ? "bg-rose-600" : "bg-emerald-600"} text-white`
    el.textContent = msg
    document.body.appendChild(el)
    setTimeout(() => el.remove(), 4000)
  }
}
