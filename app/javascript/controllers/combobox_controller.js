import { Controller } from "@hotwired/stimulus"

// Type-to-search picker over a JSON list (products, customers). Writes the chosen id to a hidden
// field and dispatches "combobox:picked" with the item so line editors can fill rate/GST.
export default class extends Controller {
  static targets = ["input", "hidden", "list"]
  static values = { source: String, items: Array, autofocus: Boolean }

  connect() {
    if (!this.itemsValue.length && this.sourceValue) {
      const el = document.getElementById(this.sourceValue)
      this.all = el ? JSON.parse(el.textContent) : []
    } else this.all = this.itemsValue
    if (this.hiddenTarget.value) {
      const cur = this.all.find(i => String(i.id) === this.hiddenTarget.value)
      if (cur && !this.inputTarget.value) this.inputTarget.value = cur.label
    }
    this.inputTarget.setAttribute("autocomplete", "off")
    if (this.autofocusValue) this.inputTarget.focus()
  }

  filter() {
    const q = this.inputTarget.value.toLowerCase().trim()
    const words = q.split(/\s+/).filter(Boolean)
    this.matches = this.all.filter(i => words.every(w => i.search.includes(w))).slice(0, 12)
    this.index = 0
    this.hiddenTarget.value = ""
    this.render()
  }

  render() {
    if (!this.matches?.length) { this.listTarget.hidden = true; return }
    this.listTarget.hidden = false
    this.listTarget.innerHTML = this.matches.map((m, i) =>
      `<li data-index="${i}" data-action="mousedown->combobox#choose" class="flex cursor-pointer items-center gap-3 px-3 py-2 text-sm ${i === this.index ? "bg-brand-50" : "hover:bg-slate-50"}">
         <span class="flex-1 truncate">${this.esc(m.label)}</span><span class="shrink-0 text-xs text-slate-400">${this.esc(m.meta || "")}</span></li>`).join("")
  }

  key(e) {
    if (this.listTarget.hidden && e.key === "ArrowDown") { this.filter(); return }
    if (this.listTarget.hidden) return
    if (e.key === "ArrowDown") { e.preventDefault(); this.index = Math.min(this.index + 1, this.matches.length - 1); this.render() }
    else if (e.key === "ArrowUp") { e.preventDefault(); this.index = Math.max(this.index - 1, 0); this.render() }
    else if (e.key === "Enter" || e.key === "Tab") { if (this.matches[this.index]) { e.preventDefault(); this.pick(this.matches[this.index]) } }
    else if (e.key === "Escape") this.listTarget.hidden = true
  }

  choose(e) { e.preventDefault(); this.pick(this.matches[+e.currentTarget.dataset.index]) }

  pick(item) {
    this.inputTarget.value = item.label
    this.hiddenTarget.value = item.id
    this.listTarget.hidden = true
    this.hiddenTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.dispatch("picked", { detail: item })
  }

  blur() { setTimeout(() => { if (this.listTarget) this.listTarget.hidden = true }, 120) }

  esc(s) { return String(s).replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c])) }
}
