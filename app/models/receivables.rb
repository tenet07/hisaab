# Everything customers still owe, bill by bill: unpaid invoices plus unpaid opening balances,
# with outstanding amounts computed in SQL (no per-invoice queries).
module Receivables
  module_function

  def open_items(customer_ids = nil)
    inv = Invoice.unpaid.with_outstanding.includes(customer: :market)
    inv = inv.where(customer_id: customer_ids) if customer_ids
    ops = LedgerEntry.where(party_type: "Customer", entry_type: "opening").where("debit_paise > 0")
    ops = ops.where(party_id: customer_ids) if customer_ids
    paid = PaymentAllocation.where(ledger_entry_id: ops.select(:id)).group(:ledger_entry_id).sum(:amount_paise)
    openings = ops.includes(party: :market).map { OpeningItem.new(_1, paid[_1.id]) }.select(&:unpaid?)
    (openings + inv.to_a).sort_by { [_1.invoice_date, _1.is_a?(OpeningItem) ? 0 : 1, _1.id] }
  end

  def ageing_bucket(item, on = Date.current)
    days = (on - item.invoice_date).to_i
    days <= 30 ? "0–30" : days <= 60 ? "31–60" : days <= 90 ? "61–90" : "90+"
  end

  def empty_ageing = { "0–30" => 0, "31–60" => 0, "61–90" => 0, "90+" => 0 }
end
