module Payments
  # Records money received (counter, salesman visit, delivery drop): credits the customer ledger
  # and matches it FIFO to the oldest unpaid invoices. Idempotent on client_uuid for offline sync.
  class Record
    class Error < StandardError; end

    def self.call(**kw) = new(**kw).call

    # apply_to: the bill this money was paid against (a counter sale), matched before older bills
    def initialize(customer:, amount_paise:, mode:, reference: nil, received_on: Date.current, client_uuid: nil, notes: nil,
                   apply_to: nil, entry_type: "payment")
      @customer, @amount, @mode, @ref = customer, amount_paise.to_i, mode, reference.presence
      @apply_to, @entry_type = apply_to, entry_type
      @date, @uuid, @notes = received_on.to_date, client_uuid.presence, notes
    end

    def call
      if @uuid && (existing = Payment.find_by(client_uuid: @uuid))
        return existing
      end
      raise Error, "Amount must be above zero" unless @amount.positive?
      raise Error, "A payment can't be dated in the future" if @date > Date.current
      Payment.transaction do
        number, = DocumentSequence.next!("payment", @date)
        pay = Payment.create!(number: number, customer: @customer, amount_paise: @amount, mode: @mode, reference: @ref,
                              received_on: @date, collected_by: Current.user, client_uuid: @uuid, notes: @notes)
        LedgerEntry.create!(party: @customer, entry_date: @date, credit_paise: @amount, entry_type: @entry_type,
                            document: pay, narration: @entry_type == "opening" ? "Opening advance" : "#{pay.mode_label} received #{number}#{" (#{@ref})" if @ref}")
        Allocate.call(@customer, first: @apply_to)
        pay
      end
    end
  end
end
