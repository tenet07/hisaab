module Stock
  # Supplier bill in: stock into sellable, supplier ledger credited.
  module PurchaseEntry
    class Error < StandardError; end
    module_function

    # items: [{ product:, quantity:, rate_paise: }]
    def call(supplier:, bill_no:, bill_date:, items:)
      items = items.select { _1[:product] && _1[:quantity].to_i.positive? }
      raise Error, "Add at least one item" if items.empty?
      Purchase.transaction do
        p = Purchase.create!(supplier: supplier, bill_no: bill_no, bill_date: bill_date, created_by: Current.user)
        items.each do |i|
          qty, rate = i[:quantity].to_i, i[:rate_paise].to_i
          taxable = qty * rate
          tax = (taxable * i[:product].gst_rate / 100).round
          p.lines.create!(product: i[:product], quantity: qty, rate_paise: rate, gst_rate: i[:product].gst_rate,
                          taxable_paise: taxable, tax_paise: tax)
          StockMovement.create!(product: i[:product], bucket: "sellable", quantity: qty, reason: "purchase", document: p)
          i[:product].update!(purchase_paise: rate) if rate.positive?
        end
        p.update!(taxable_paise: p.lines.sum(:taxable_paise), tax_paise: p.lines.sum(:tax_paise),
                  total_paise: p.lines.sum("taxable_paise + tax_paise"))
        LedgerEntry.create!(party: supplier, entry_date: bill_date, credit_paise: p.total_paise, entry_type: "purchase",
                            document: p, narration: "Bill #{bill_no}")
        p
      end
    end
  end
end
