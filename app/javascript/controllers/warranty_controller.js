import { Controller } from "@hotwired/stimulus"

// Looks up the sale invoice and warranty as soon as both customer and product are picked.
export default class extends Controller {
  static targets = ["result", "invoice", "outcome"]

  async check() {
    const c = this.element.querySelector("input[name=customer_id]").value
    const p = this.element.querySelector("input[name=product_id]").value
    if (!c || !p) return
    const res = await fetch(`/replacements/warranty?customer_id=${c}&product_id=${p}`, { headers: { Accept: "application/json" } })
    const w = await res.json()
    const box = this.resultTarget
    box.classList.remove("hidden", "border-emerald-200", "bg-emerald-50", "border-rose-200", "bg-rose-50", "border-amber-200", "bg-amber-50")
    this.invoiceTarget.value = w.invoice_id || ""
    if (!w.invoice) {
      box.classList.add("border-amber-200", "bg-amber-50")
      box.innerHTML = `<b>No sale found</b> of this item to this customer. Warranty can't be confirmed — bill a new piece or return it.`
      this.pick("charged")
    } else if (w.valid) {
      box.classList.add("border-emerald-200", "bg-emerald-50")
      box.innerHTML = `<b>In warranty</b> until ${w.warranty_until}. Sold on ${w.sold_on}, invoice ${w.invoice}. ${w.stock > 0 ? `${w.stock} good pieces in stock to swap.` : `<span class="text-rose-700">No stock to swap!</span>`}`
      this.pick("swapped")
    } else {
      box.classList.add("border-rose-200", "bg-rose-50")
      box.innerHTML = `<b>Out of warranty</b> since ${w.warranty_until} (sold ${w.sold_on}, ${w.invoice}). Bill a new piece or return it.`
      this.pick("charged")
    }
  }

  pick(v) { const r = this.outcomeTargets.find(o => o.value === v); if (r) r.checked = true }
}
