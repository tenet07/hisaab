module Invoicing
  # A credit note against an invoice: shortfall at delivery, return, rate difference or a defective
  # piece not replaced. Credits the customer; returned pieces go back into the chosen stock bucket.
  class CreditNote
    class Error < StandardError; end

    # items: [{ invoice_line:, quantity:, rate_paise: (rate difference only) }]
    def self.call(**kw) = new(**kw).call

    def initialize(invoice:, reason:, items:, restock_bucket: nil, date: Date.current, notes: nil)
      @invoice, @reason, @items, @bucket, @date, @notes = invoice, reason, items, restock_bucket.presence, date.to_date, notes
    end

    def call
      raise Error, "Credit notes can only be raised on a posted invoice" unless @invoice.posted?
      items = @items.select { _1[:quantity].to_i.positive? }
      raise Error, "Pick at least one line and quantity" if items.empty?
      already = @invoice.credited_qty_by_line
      calc = Gst::Calculator.new(interstate: @invoice.igst_paise.positive?, inclusive: false)
      line_ids = []
      items.each do |i|
        line = i[:invoice_line]
        left = line.quantity - already[line.id].to_i
        raise Error, "#{line.description}: only #{left} left to credit" if i[:quantity].to_i > left
        # credit at the invoiced net rate (taxable per piece) unless this is a rate difference
        rate = i[:rate_paise] || (line.taxable_paise.to_d / line.quantity).round
        calc.add(product: line.product, quantity: i[:quantity], rate_paise: rate)
        line_ids << line.id
      end

      ::CreditNote.transaction do
        number, fy = DocumentSequence.next!("credit_note", @date)
        total = calc.exact_paise
        raise Error, "Credit exceeds what is still owed on this invoice" if total > @invoice.total_paise - @invoice.credited_paise
        cn = ::CreditNote.create!(number: number, fy: fy, customer: @invoice.customer, invoice: @invoice, note_date: @date,
                                  reason: @reason, restock_bucket: @bucket, taxable_paise: calc.taxable_paise,
                                  cgst_paise: calc.cgst_paise, sgst_paise: calc.sgst_paise, igst_paise: calc.igst_paise,
                                  total_paise: total, created_by: Current.user, notes: @notes)
        calc.lines.zip(line_ids).each do |l, line_id|
          cn.lines.create!(product: l.product, invoice_line_id: line_id, quantity: l.quantity,
                           rate_paise: l.rate_paise, gst_rate: l.gst_rate, taxable_paise: l.taxable_paise,
                           tax_paise: l.cgst_paise + l.sgst_paise + l.igst_paise, total_paise: l.total_paise)
          next unless @bucket && @reason != "rate_difference"
          StockMovement.create!(product: l.product, bucket: @bucket, quantity: l.quantity,
                                reason: @reason == "shortfall" ? "shortfall" : "return", document: cn)
        end
        LedgerEntry.create!(party: @invoice.customer, entry_date: @date, credit_paise: total, entry_type: "credit_note",
                            document: cn, narration: "Credit note #{number} (#{cn.reason_label}) on #{@invoice.number}")
        # a payment matched beyond the reduced invoice value goes back to on-account
        Payments::Allocate.trim(@invoice)
        Payments::Allocate.call(@invoice.customer)
        cn
      end
    end
  end
end
