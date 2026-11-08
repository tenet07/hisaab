import { Controller } from "@hotwired/stimulus"

// Bill builder: searchable customer + item pickers, qty steppers and a live
// total. The form still posts customer_id, items[n][product_id|qty|discount]
// and deliver; the server recalculates everything, so the total here is a preview.
const inr = (paise, decimals = true) => {
  const neg = paise < 0, p = Math.abs(Math.round(paise))
  const rupees = Math.floor(p / 100), ps = String(p % 100).padStart(2, "0")
  const s = String(rupees), last3 = s.slice(-3), head = s.slice(0, -3)
  const grouped = head ? head.replace(/\B(?=(\d{2})+(?!\d))/g, ",") + "," + last3 : last3
  return (neg ? "-" : "") + "₹" + grouped + (decimals ? "." + ps : "")
}
const divRound = (num, den) => Math.floor((num + Math.floor(den / 2)) / den) // half-up, non-negative
const toPaise = (v) => { const n = parseFloat(String(v).replace(/[^\d.]/g, "")); return isNaN(n) ? 0 : Math.round(n * 100) }
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]))
const matches = (hay, q) => q.toLowerCase().split(/\s+/).filter(Boolean).every((t) => hay.includes(t))

export default class extends Controller {
  static targets = ["customers", "products", "customerId", "chosen", "chosenName", "chosenMeta", "custPicker", "custQuery", "custList",
                    "prodPicker", "prodQuery", "prodList", "lines", "linesEmpty", "totals", "taxable", "tax", "round", "roundRow",
                    "total", "count", "save", "deliver", "limitWarn"]

  connect() {
    this.customers = JSON.parse(this.customersTarget.textContent)
    this.products = JSON.parse(this.productsTarget.textContent)
    this.byId = Object.fromEntries(this.products.map((p) => [p.id, p]))
    this.n = 0
    this.deliverManual = false
    this.custIdx = 0; this.prodIdx = 0
    this.customer = this.customers.find((c) => String(c.id) === this.customerIdTarget.value) || null
    if (this.customer) this.showChosen()
    this.outside = (e) => { if (!this.element.contains(e.target) || !e.target.closest(".picker")) this.closeLists() }
    document.addEventListener("click", this.outside)
    this.recalc()
  }
  disconnect() { document.removeEventListener("click", this.outside) }

  // ---------------------------------------------------------------- customer
  custSearch() {
    const q = this.custQueryTarget.value.trim()
    const list = (q ? this.customers.filter((c) => matches(`${c.name} ${c.market} ${c.phone}`.toLowerCase(), q)) : this.customers).slice(0, 30)
    this.custResults = list; this.custIdx = 0
    this.render(this.custListTarget, this.custQueryTarget, list.map((c) => `
      <span class="pk-main"><span class="pk-title">${esc(c.name)}</span><br><span class="pk-sub">${esc(c.market)}${c.phone ? " · " + esc(c.phone) : ""} · ${c.tier}</span></span>
      <span class="pk-end ${c.bal > 0 ? "due" : ""}">${inr(c.bal, false)}<br><span class="pk-sub">due</span></span>`), "No shop matches. Check the spelling.",
      (i) => this.pickCustomer(this.custResults[i]))
  }
  custKey(e) { this.listKey(e, this.custListTarget, this.custQueryTarget, () => this.custResults, "custIdx", (c) => this.pickCustomer(c)) }
  pickCustomer(c) {
    if (!c) return
    this.customer = c
    this.customerIdTarget.value = c.id
    this.closeLists()
    this.showChosen()
    if (!this.deliverManual) this.deliverTarget.checked = c.tier === "wholesale"
    this.repriceLines()
    this.prodQueryTarget.focus()
  }
  showChosen() {
    const c = this.customer
    this.chosenNameTarget.textContent = c.name
    this.chosenMetaTarget.innerHTML = `${esc(c.market)} · ${c.tier === "retail" ? "Retail" : "Wholesale"} prices · <span class="${c.bal > 0 ? "due" : ""}">${inr(c.bal, false)} due</span>`
    this.chosenTarget.hidden = false
    this.custPickerTarget.hidden = true
  }
  changeCustomer() {
    this.chosenTarget.hidden = true
    this.custPickerTarget.hidden = false
    this.custQueryTarget.value = ""
    this.custQueryTarget.focus()
  }
  deliverTouched() { this.deliverManual = true }

  // ---------------------------------------------------------------- products
  prodSearch() {
    const q = this.prodQueryTarget.value.trim()
    const list = (q ? this.products.filter((p) => matches(`${p.brand} ${p.name} ${p.sku}`.toLowerCase(), q)) : this.products).slice(0, 40)
    this.prodResults = list; this.prodIdx = 0
    this.render(this.prodListTarget, this.prodQueryTarget, list.map((p) => `
      <span class="pk-main"><span class="pk-title">${esc(p.brand)} ${esc(p.name)}</span><br><span class="pk-sub">${esc(p.sku)} · ${p.stock > 0 ? p.stock + " in stock" : '<span class="due">out of stock</span>'}</span></span>
      <span class="pk-end">${inr(this.price(p))}<br><span class="pk-sub">${p.incl ? "incl." : "+"} ${p.gst / 100}% GST</span></span>`), "No item matches. Try the brand or the wattage, e.g. \"9w\".",
      (i) => this.addProduct(this.prodResults[i]))
  }
  prodKey(e) { this.listKey(e, this.prodListTarget, this.prodQueryTarget, () => this.prodResults, "prodIdx", (p) => this.addProduct(p)) }

  addProduct(p) {
    if (!p) return
    const existing = this.linesTarget.querySelector(`[data-pid="${p.id}"]`)
    this.prodQueryTarget.value = ""
    this.closeLists()
    if (existing) {
      const q = existing.querySelector("[data-qty]")
      q.value = (parseInt(q.value) || 0) + 1
      this.recalc(); q.focus(); q.select()
      return
    }
    const i = this.n++
    const li = document.createElement("li")
    li.className = "line"; li.dataset.pid = p.id
    li.innerHTML = `
      <input type="hidden" name="items[${i}][product_id]" value="${p.id}">
      <div><div class="l-name">${esc(p.brand)} ${esc(p.name)}</div><div class="l-meta" data-meta></div></div>
      <div class="l-total" data-line-total></div>
      <div class="l-ctrl">
        <div class="stepper"><button type="button" aria-label="One less" data-action="bill#dec">−</button>
          <input type="number" name="items[${i}][qty]" value="1" min="1" inputmode="numeric" aria-label="Quantity of ${esc(p.brand)} ${esc(p.name)}" data-qty data-action="input->bill#recalc">
          <button type="button" aria-label="One more" data-action="bill#inc">+</button></div>
        <label class="l-disc">Discount <span class="money-in"><input type="text" name="items[${i}][discount]" inputmode="decimal" placeholder="0" aria-label="Discount in rupees on ${esc(p.brand)} ${esc(p.name)}" data-disc data-action="input->bill#recalc"></span></label>
        <button type="button" class="icon-btn l-rm" aria-label="Remove ${esc(p.brand)} ${esc(p.name)}" data-action="bill#remove">
          <svg class="ic" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" aria-hidden="true"><path d="M6 6l12 12M18 6L6 18"/></svg></button>
      </div>
      <div class="l-warn" data-warn hidden></div>`
    this.linesTarget.appendChild(li)
    this.recalc()
    const q = li.querySelector("[data-qty]"); q.focus(); q.select()
  }
  inc(e) { this.step(e, 1) }
  dec(e) { this.step(e, -1) }
  step(e, d) {
    const q = e.currentTarget.closest(".line").querySelector("[data-qty]")
    q.value = Math.max(1, (parseInt(q.value) || 0) + d)
    this.recalc()
  }
  remove(e) {
    e.currentTarget.closest(".line").remove()
    this.recalc()
    this.prodQueryTarget.focus()
  }

  // ---------------------------------------------------------------- totals
  price(p) { return this.customer && this.customer.tier === "retail" ? p.r : p.w }
  repriceLines() { this.recalc() }
  recalc() {
    let taxable = 0, tax = 0, pieces = 0, lines = 0, problem = false
    this.linesTarget.querySelectorAll(".line").forEach((li) => {
      const p = this.byId[li.dataset.pid]
      const qty = Math.max(0, parseInt(li.querySelector("[data-qty]").value) || 0)
      const disc = toPaise(li.querySelector("[data-disc]").value)
      const unit = this.price(p)
      const gross = qty * unit - disc
      let t, x
      if (p.incl) { t = divRound(Math.max(gross, 0) * 10000, 10000 + p.gst); x = Math.max(gross, 0) - t }
      else { t = Math.max(gross, 0); x = divRound(t * p.gst, 10000) }
      taxable += t; tax += x; pieces += qty; lines += 1
      li.querySelector("[data-meta]").textContent = `${inr(unit)} each${disc ? " − " + inr(disc) + " off" : ""} · ${p.incl ? "incl." : "+"} ${p.gst / 100}% GST`
      li.querySelector("[data-line-total]").textContent = inr(t + x)
      const warn = li.querySelector("[data-warn]")
      let msg = ""
      if (gross < 0) msg = "Discount is more than the item value."
      else if (qty > p.stock) msg = `Only ${p.stock} in stock.`
      warn.textContent = msg; warn.hidden = !msg
      if (msg || qty < 1) problem = true
    })
    const exact = taxable + tax
    const total = divRound(exact, 100) * 100
    this.taxableTarget.textContent = inr(taxable)
    this.taxTarget.textContent = inr(tax)
    this.roundTarget.textContent = inr(total - exact)
    this.roundRowTarget.hidden = total === exact
    this.totalsTarget.hidden = lines === 0
    this.linesEmptyTarget.hidden = lines > 0
    this.totalTarget.textContent = inr(total, false)
    this.countTarget.textContent = lines ? `${lines} item${lines > 1 ? "s" : ""} · ${pieces} pieces · incl. GST` : "No items"
    const ready = this.customer && lines > 0 && !problem
    this.saveTarget.disabled = !ready
    this.saveTarget.title = !this.customer ? "Choose a customer first" : !lines ? "Add at least one item" : problem ? "Fix the item marked in red" : ""
    // credit-limit heads-up (does not block; the office decides)
    const c = this.customer
    if (c && c.limit > 0 && c.bal + total > c.limit) {
      this.limitWarnTarget.hidden = false
      this.limitWarnTarget.querySelector("p").textContent = `After this bill ${c.name} will owe ${inr(c.bal + total, false)}, above their limit of ${inr(c.limit, false)}.`
    } else this.limitWarnTarget.hidden = true
  }

  // ---------------------------------------------------------------- list mechanics
  render(listEl, input, rows, emptyMsg, onPick) {
    listEl.innerHTML = rows.length
      ? rows.map((html, i) => `<li role="option" id="${listEl.id}-${i}" aria-selected="${i === 0}" data-i="${i}">${html}</li>`).join("")
      : `<li class="none" role="option" aria-disabled="true">${esc(emptyMsg)}</li>`
    listEl.hidden = false
    input.setAttribute("aria-expanded", "true")
    input.setAttribute("aria-activedescendant", rows.length ? `${listEl.id}-0` : "")
    listEl.querySelectorAll("li[data-i]").forEach((li) => li.addEventListener("mousedown", (e) => { e.preventDefault(); onPick(+li.dataset.i) }))
  }
  listKey(e, listEl, input, results, idxName, pick) {
    if (listEl.hidden && (e.key === "ArrowDown")) { input.dispatchEvent(new Event("input")); return }
    const n = (results() || []).length
    if (e.key === "ArrowDown" || e.key === "ArrowUp") {
      e.preventDefault()
      if (!n) return
      this[idxName] = (this[idxName] + (e.key === "ArrowDown" ? 1 : n - 1)) % n
      listEl.querySelectorAll("li[data-i]").forEach((li) => li.setAttribute("aria-selected", +li.dataset.i === this[idxName]))
      const cur = listEl.querySelector(`[data-i="${this[idxName]}"]`)
      cur?.scrollIntoView({ block: "nearest" })
      input.setAttribute("aria-activedescendant", cur?.id || "")
    } else if (e.key === "Enter") {
      e.preventDefault()
      if (!listEl.hidden && n) pick(results()[this[idxName]])
    } else if (e.key === "Escape") { this.closeLists() }
  }
  closeLists() {
    [[this.custListTarget, this.custQueryTarget], [this.prodListTarget, this.prodQueryTarget]].forEach(([l, i]) => { l.hidden = true; i.setAttribute("aria-expanded", "false") })
  }
  // Enter in a qty/discount box goes back to the item search instead of saving half a bill.
  formKey(e) {
    if (e.key !== "Enter") return
    const t = e.target
    if (t.matches("[data-qty],[data-disc]")) { e.preventDefault(); this.prodQueryTarget.focus() }
    else if (t.matches("input[type=checkbox]")) e.preventDefault()
  }
  submit(e) {
    if (this.saveTarget.disabled) { e.preventDefault(); return }
    this.saveTarget.value = "Saving…"
  }
}
