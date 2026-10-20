module Invoicing
  # A credit note against an invoice: shortfall at delivery, return, rate difference or a defective
  # piece not replaced. Credits back exactly what the invoice charged for those pieces — a full
  # return reverses the invoice to the paisa, round-off included.
  class CreditNote
    class Error < StandardError; end

    # Where returned pieces go. Defective pieces come back through a replacement, not a credit note.
    RESTOCK = { "shortfall" => "sellable", "return" => "sellable", "rate_difference" => nil, "defective" => nil }.freeze

    # items: [{ invoice_line:, quantity:, rate_paise: (rate difference: reduction per piece, ex-GST) }]
    def self.call(**kw) = new(**kw).call

    def initialize(invoice:, reason:, items:, restock_bucket: :default, date: Date.current, notes: nil)
      raise Error, "Pick a reason" unless RESTOCK.key?(reason)
      @invoice, @reason, @items, @date, @notes = invoice, reason, items, date.to_date, notes
      @bucket = restock_bucket == :default ? RESTOCK[reason] : restock_bucket.presence
      raise Error, "Returned pieces can only go back to sellable stock" if @bucket && @bucket != "sellable"
    end

    def call
      raise Error, "Credit notes can only be raised on a posted invoice" unless @invoice.posted?
      items = @items.select { _1[:quantity].to_i.positive? }
      raise Error, "Pick at least one line and quantity" if items.empty?
      credited = credited_by_line
      igst = @invoice.igst_paise.positive?

      rows = items.map do |i|
        line = i[:invoice_line]
        done = credited[line.id] || { qty: 0, taxable: 0, tax: 0 }
        left = line.quantity - done[:qty]
        q = i[:quantity].to_i
        raise Error, "#{line.description}: only #{left} left to credit" if q > left && @reason != "rate_difference"
        if @reason == "rate_difference"
          per_piece = (line.taxable_paise.to_d / line.quantity).floor
          rate = i[:rate_paise].to_i
          raise Error, "#{line.description}: enter the rate reduction per piece" unless rate.positive?
          raise Error, "#{line.description}: the reduction can't exceed the net rate of #{Money.format(per_piece)}" if rate > per_piece
          raise Error, "#{line.description}: only #{line.quantity} were billed" if q > line.quantity
          taxable = q * rate
          tax = (taxable * line.gst_rate / 100).round
        elsif q == left
          # the last pieces of a line take whatever is left, so a full return nets to zero
          taxable = line.taxable_paise - done[:taxable]
          tax = line.tax_paise - done[:tax]
        else
          taxable = (line.taxable_paise * q.to_d / line.quantity).round
          tax = (line.tax_paise * q.to_d / line.quantity).round
        end
        { line: line, qty: q, rate: (taxable.to_d / q).round, taxable: taxable, tax: tax }
      end

      ::CreditNote.transaction do
        @invoice.lock!
        taxable = rows.sum { _1[:taxable] }
        tax = rows.sum { _1[:tax] }
        cgst = igst ? 0 : tax / 2
        sgst = igst ? 0 : tax - cgst
        fully_returned = @reason != "rate_difference" && @invoice.lines.all? do |l|
          (credited[l.id]&.dig(:qty) || 0) + rows.select { _1[:line] == l }.sum { _1[:qty] } >= l.quantity
        end
        round_off = fully_returned ? @invoice.total_paise - @invoice.credited_paise - taxable - tax : 0
        total = taxable + tax + round_off
        raise Error, "Credit exceeds what is still owed on this invoice" if total > @invoice.total_paise - @invoice.credited_paise

        number, fy = DocumentSequence.next!("credit_note", @date)
        cn = ::CreditNote.create!(number: number, fy: fy, customer: @invoice.customer, invoice: @invoice, note_date: @date,
                                  reason: @reason, restock_bucket: @bucket, taxable_paise: taxable, cgst_paise: cgst, sgst_paise: sgst,
                                  igst_paise: igst ? tax : 0, round_off_paise: round_off, total_paise: total,
                                  created_by: Current.user, notes: @notes)
        rows.each do |r|
          cn.lines.create!(product: r[:line].product, invoice_line: r[:line], quantity: r[:qty], rate_paise: r[:rate],
                           gst_rate: r[:line].gst_rate, taxable_paise: r[:taxable], tax_paise: r[:tax], total_paise: r[:taxable] + r[:tax])
          next unless @bucket
          StockMovement.create!(product: r[:line].product, bucket: @bucket, quantity: r[:qty],
                                reason: @reason == "shortfall" ? "shortfall" : "return", document: cn)
        end
        LedgerEntry.create!(party: @invoice.customer, entry_date: @date, credit_paise: total, entry_type: "credit_note",
                            document: cn, narration: "Credit note #{number} (#{cn.reason_label}) on #{@invoice.number}")
        Payments::Allocate.trim(@invoice)
        Payments::Allocate.call(@invoice.customer)
        cn
      end
    end

    private

    def credited_by_line
      CreditNoteLine.joins(:credit_note).where(credit_notes: { invoice_id: @invoice.id }).where.not(credit_notes: { reason: "rate_difference" })
                    .group(:invoice_line_id).pluck(:invoice_line_id, Arel.sql("SUM(credit_note_lines.quantity)"), Arel.sql("SUM(credit_note_lines.taxable_paise)"), Arel.sql("SUM(credit_note_lines.tax_paise)"))
                    .to_h { |id, q, t, x| [id, { qty: q.to_i, taxable: t.to_i, tax: x.to_i }] }
    end
  end
end
