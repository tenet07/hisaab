module Payments
  # FIFO matching: a customer's unmatched payment money goes to their oldest unpaid invoices first.
  module Allocate
    module_function

    def call(customer)
      Payment.transaction do
        invoices = customer.invoices.posted.order(:invoice_date, :id).lock.to_a.select(&:unpaid?)
        customer.payments.cleared.order(:received_on, :id).each do |pay|
          left = pay.unallocated_paise
          next unless left.positive?
          invoices.each do |inv|
            break unless left.positive?
            owed = inv.outstanding_paise
            next unless owed.positive?
            amt = [owed, left].min
            pay.allocations.create!(invoice: inv, amount_paise: amt, created_at: Time.current)
            inv.payment_allocations.reset
            left -= amt
          end
        end
      end
    end

    # After a credit note, an invoice can be over-matched; release the excess (latest payment first).
    def trim(invoice)
      excess = invoice.paid_paise + invoice.credited_paise - invoice.total_paise
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
