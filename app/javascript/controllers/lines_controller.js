import { Controller } from "@hotwired/stimulus"

// Line-item editor for orders, invoices, purchases and the counter bill.
// Totals here are a live estimate; the server's GST calculator is the source of truth.
export default class extends Controller {
  static targets = ["body", "template", "taxable", "tax", "total", "count"]
  static values = { inclusive: Boolean, tier: String, rateKey: { type: String, default: "price" } }

  connect() { if (!this.bodyTarget.querySelector("tr")) this.add(); this.recalc() }

  add(e) {
    e?.preventDefault()
    const html = this.templateTarget.innerHTML.replace(/NEW_LINE/g, Date.now() + Math.floor(Math.random() * 1000))
    this.bodyTarget.insertAdjacentHTML("beforeend", html)
    const rows = this.bodyTarget.querySelectorAll("tr")
    rows[rows.length - 1].querySelector("input[type=text]")?.focus()
  }

  remove(e) {
    e.preventDefault()
    const row = e.target.closest("tr")
    const destroy = row.querySelector("input[name*='_destroy']")
    if (destroy) { destroy.value = "1"; row.hidden = true } else row.remove()
    this.recalc()
  }

  picked(e) {
    const row = e.target.closest("tr"), item = e.detail
    const rate = row.querySelector("[data-field=rate]")
    const tierPrice = item.prices ? (item.prices[this.tierValue] ?? item.prices.wholesale) : item[this.rateKeyValue]
    if (rate) rate.value = (tierPrice / 100).toFixed(2)
    row.dataset.gst = item.gst
    const stock = row.querySelector("[data-field=stock]")
    if (stock) { stock.textContent = item.stock; stock.className = item.stock > 0 ? "text-slate-500" : "text-rose-600 font-medium" }
    const qty = row.querySelector("[data-field=qty]")
    if (qty) { if (!qty.value) qty.value = 1; qty.focus(); qty.select() }
    this.recalc()
  }

  // Product tile on the counter screen: bump qty if already in the bill, else add a line
  tile(e) {
    const item = JSON.parse(e.currentTarget.dataset.item)
    const rows = [...this.bodyTarget.querySelectorAll("tr:not([hidden])")]
    const hit = rows.find(r => r.querySelector("input[type=hidden][name$='[product_id]']")?.value === String(item.id))
    if (hit) {
      const q = hit.querySelector("[data-field=qty]"); q.value = (parseInt(q.value) || 0) + 1; this.recalc(); return
    }
    let row = rows.find(r => !r.querySelector("input[type=hidden][name$='[product_id]']")?.value)
    if (!row) { this.add(); row = [...this.bodyTarget.querySelectorAll("tr")].pop() }
    row.querySelector("input[type=hidden][name$='[product_id]']").value = item.id
    row.querySelector("input[type=text]").value = item.label
    row.querySelector("[data-field=qty]").value = 1
    this.picked({ target: row.querySelector("input[type=text]"), detail: item })
  }

  // Customer picked: switch the price tier and whether prices include GST
  customer(e) {
    this.tierValue = e.detail.tier || "wholesale"
    this.inclusiveValue = !e.detail.b2b
    const badge = this.element.querySelector("[data-price-mode]")
    if (badge) badge.textContent = this.inclusiveValue ? "Prices include GST (B2C)" : "Prices + GST (B2B)"
    this.recalc()
  }

  // Enter in the last qty field adds a fresh line, like Tally/Vyapar billing
  qtyKey(e) {
    if (e.key !== "Enter") return
    e.preventDefault()
    const rows = [...this.bodyTarget.querySelectorAll("tr:not([hidden])")]
    if (e.target.closest("tr") === rows[rows.length - 1]) this.add()
  }

  recalc() {
    let taxable = 0, tax = 0, n = 0
    this.bodyTarget.querySelectorAll("tr:not([hidden])").forEach(row => {
      const q = parseFloat(row.querySelector("[data-field=qty]")?.value) || 0
      const r = parseFloat(row.querySelector("[data-field=rate]")?.value) || 0
      const d = parseFloat(row.querySelector("[data-field=disc]")?.value) || 0
      const g = parseFloat(row.dataset.gst) || 0
      const gross = q * r * (100 - d) / 100
      const t = this.inclusiveValue ? gross * 100 / (100 + g) : gross
      const x = this.inclusiveValue ? gross - t : t * g / 100
      taxable += t; tax += x
      if (q > 0) n++
      const amt = row.querySelector("[data-field=amount]")
      if (amt) amt.textContent = this.inr(t + x)
    })
    const total = Math.round(taxable + tax)
    if (this.hasTaxableTarget) this.taxableTarget.textContent = this.inr(taxable)
    if (this.hasTaxTarget) this.taxTarget.textContent = this.inr(tax)
    if (this.hasTotalTarget) this.totalTarget.textContent = this.inr(total, 0)
    if (this.hasCountTarget) this.countTarget.textContent = n
  }

  inr(v, digits = 2) { return "₹" + v.toLocaleString("en-IN", { minimumFractionDigits: digits, maximumFractionDigits: digits }) }
}
