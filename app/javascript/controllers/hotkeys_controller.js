import { Controller } from "@hotwired/stimulus"

// Single-key shortcuts for the busy counter: B bill, P payment, O orders, R replacement, / search.
const KEYS = { b: "/counter", p: "/payments/new", o: "/orders", r: "/replacements/new", s: "/stock", c: "/customers" }

export default class extends Controller {
  keydown(e) {
    if (e.metaKey || e.ctrlKey || e.altKey) return
    const t = e.target
    if (t.isContentEditable || ["INPUT", "TEXTAREA", "SELECT"].includes(t.tagName)) return
    const url = KEYS[e.key.toLowerCase()]
    if (url) { e.preventDefault(); Turbo.visit(url) }
  }
}
