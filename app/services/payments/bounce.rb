module Payments
  # A cheque bounced: the customer is debited back, its invoice matches are released.
  module Bounce
    module_function

    def call(payment, reason:)
      raise ArgumentError, "Already marked bounced" if payment.bounced?
      raise ArgumentError, "Only cheques can bounce" unless payment.mode == "cheque"
      Payment.transaction do
        LedgerEntry.create!(party: payment.customer, entry_date: Date.current, debit_paise: payment.amount_paise,
                            entry_type: "payment_bounce", document: payment, narration: "Bounced #{payment.number}: #{reason}")
        payment.allocations.destroy_all
        payment.update!(status: "bounced", notes: [payment.notes, "Bounced: #{reason}"].compact.join("\n"))
        AuditEvent.log!(payment, "bounced", { "reason" => reason })
        Allocate.call(payment.customer)
        payment
      end
    end
  end
end
