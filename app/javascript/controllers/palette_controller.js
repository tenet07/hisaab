import { Controller } from "@hotwired/stimulus"

// ⌘K command palette: jump to any customer, invoice, product or screen.
export default class extends Controller {
  static targets = ["dialog", "input", "results"]

  keydown(e) {
    if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") { e.preventDefault(); this.open() }
    else if (e.key === "Escape" && !this.dialogTarget.hidden) this.close()
  }

  open() {
    this.dialogTarget.hidden = false
    this.inputTarget.value = ""
    this.inputTarget.focus()
    this.search()
  }

  close() { this.dialogTarget.hidden = true }
  backdrop(e) { if (e.target === this.dialogTarget) this.close() }

  async search() {
    const q = this.inputTarget.value
    clearTimeout(this.timer)
    this.timer = setTimeout(async () => {
      const res = await fetch(`/search?q=${encodeURIComponent(q)}`, { headers: { Accept: "application/json" } })
      if (!res.ok) return
      this.items = await res.json()
      this.index = 0
      this.render()
    }, 90)
  }

  render() {
    let group = null
    this.resultsTarget.innerHTML = this.items.map((it, i) => {
      const head = it.group !== group ? `<li class="px-2 pt-2 pb-1 text-[11px] font-semibold uppercase tracking-wider text-slate-400">${it.group}</li>` : ""
      group = it.group
      return `${head}<li><a href="${it.url}" data-index="${i}" class="flex items-center gap-3 rounded-lg px-3 py-2 text-sm ${i === this.index ? "bg-brand-50 text-brand-800" : "text-slate-700 hover:bg-slate-50"}">
        <span class="flex-1 truncate">${this.esc(it.title)}</span><span class="truncate text-xs text-slate-400">${this.esc(it.sub || "")}</span></a></li>`
    }).join("") || `<li class="px-3 py-6 text-center text-sm text-slate-400">Nothing found</li>`
  }

  nav(e) {
    if (!this.items?.length) return
    if (e.key === "ArrowDown") { e.preventDefault(); this.index = (this.index + 1) % this.items.length; this.render() }
    if (e.key === "ArrowUp") { e.preventDefault(); this.index = (this.index - 1 + this.items.length) % this.items.length; this.render() }
    if (e.key === "Enter") { e.preventDefault(); this.close(); Turbo.visit(this.items[this.index].url) }
  }

  esc(s) { return String(s).replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c])) }
}
