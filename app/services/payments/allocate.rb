module Payments
  # FIFO matching: a customer's unmatched payment money goes to the oldest unpaid item first —
  # an opening balance brought in from the old books, then invoices by date.
  module Allocate
    module_function

    def call(customer, first: nil)
      Payment.transaction do
        Customer.lock.find(customer.id) # one allocator per customer at a time
        items = Receivables.open_items([customer.id])
        items.unshift(items.delete(first)) if first && items.include?(first)
        owed = items.to_h { [key(_1), _1.outstanding_paise] }
        customer.payments.cleared.order(:received_on, :id).each do |pay|
          left = pay.unallocated_paise
          next unless left.positive?
          items.each do |item|
            break unless left.positive?
            due = owed[key(item)]
            next unless due.positive?
            amt = [due, left].min
            target = item.is_a?(OpeningItem) ? { ledger_entry_id: item.entry.id } : { invoice_id: item.id }
            pay.allocations.create!(target.merge(amount_paise: amt, created_at: Time.current))
            owed[key(item)] -= amt
            left -= amt
          end
        end
      end
    end

    def key(item) = [item.class.name, item.id]

    # After a credit note, an invoice can be over-matched; release the excess (latest payment first).
    def trim(invoice)
      excess = invoice.payment_allocations.sum(:amount_paise) + invoice.credit_notes.sum(:total_paise) - invoice.total_paise
      invoice.payment_allocations.order(id: :desc).each do |a|
        break unless excess.positive?
        cut = [a.amount_paise, excess].min
        cut == a.amount_paise ? a.destroy! : a.update!(amount_paise: a.amount_paise - cut)
        excess -= cut
      end
      invoice.payment_allocations.reset
    end
  end
end
