module Invoicing
  # Cancels a posted invoice by reversal: stock comes back in, the customer is credited, and any
  # payments that were matched to it are freed and re-matched FIFO. Nothing is deleted.
  class Cancel
    class Error < StandardError; end

    def self.call(invoice, reason:) = new(invoice, reason).call

    def initialize(invoice, reason)
      @invoice, @reason = invoice, reason.to_s.strip
    end

    def call
      raise Error, "Give a reason for cancelling" if @reason.blank?
      raise Error, "Already cancelled" if @invoice.cancelled?
      raise Error, "This invoice has credit notes; reverse those first" if @invoice.credit_notes.any?
      raise Error, "Delivered already — issue a return credit note instead" if @invoice.delivery&.done?

      Invoice.transaction do
        @invoice.lock!
        @invoice.lines.each do |l|
          StockMovement.create!(product: l.product, bucket: "sellable", quantity: l.quantity, reason: "sale_reversal",
                                document: @invoice, note: "Cancelled: #{@reason}")
        end
        LedgerEntry.create!(party: @invoice.customer, entry_date: Date.current, credit_paise: @invoice.total_paise,
                            entry_type: "invoice_reversal", document: @invoice, narration: "Cancelled #{@invoice.number}: #{@reason}")
        @invoice.payment_allocations.destroy_all
        @invoice.delivery&.destroy!
        @invoice.update!(status: "cancelled", cancelled_by: Current.user, cancelled_at: Time.current, cancel_reason: @reason)
        AuditEvent.log!(@invoice, "cancelled", { "reason" => @reason })
        Payments::Allocate.call(@invoice.customer)
        @invoice
      end
    end
  end
end
