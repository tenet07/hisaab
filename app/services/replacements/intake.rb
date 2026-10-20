module Replacements
  # A customer brings back a defective piece. Warranty is read from the invoice that sold it.
  # A swap is two movements: the defective piece into awaiting_claim, a good one out of sellable.
  class Intake
    class Error < StandardError; end

    def self.call(**kw) = new(**kw).call

    def self.lookup(customer, product)
      inv = customer.invoices.posted.joins(:lines).where(invoice_lines: { product_id: product.id }).order(invoice_date: :desc).first
      return { invoice: nil, sold_on: nil, warranty_until: nil, valid: false } unless inv
      until_date = inv.invoice_date >> product.effective_warranty_months
      { invoice: inv, sold_on: inv.invoice_date, warranty_until: until_date, valid: Date.current <= until_date }
    end

    def initialize(customer:, product:, outcome:, invoice: nil, defect: nil, serial_no: nil, channel: "counter",
                   client_uuid: nil, goodwill: false)
      @customer, @product, @outcome, @invoice = customer, product, outcome, invoice
      @defect, @serial, @channel, @uuid, @goodwill = defect, serial_no, channel, client_uuid.presence, goodwill
    end

    def call
      if @uuid && (r = Replacement.find_by(client_uuid: @uuid))
        return r
      end
      if @invoice && (@invoice.customer_id != @customer.id || !@invoice.posted? || @invoice.lines.none? { _1.product_id == @product.id })
        raise Error, "Invoice #{@invoice.number} didn't sell #{@product.display_name} to #{@customer.shop_name}"
      end
      info = @invoice ? self.class.lookup_on(@invoice, @product) : self.class.lookup(@customer, @product)
      if @outcome == "swapped" && !info[:valid]
        raise Error, info[:invoice] ? "Out of warranty (ended #{info[:warranty_until].strftime('%d %b %Y')}). Bill a new piece instead." : "No invoice found for this product to this customer — warranty can't be checked." unless @goodwill
        raise Error, "Only the owner can approve a goodwill swap" unless Current.user&.owner?
      end

      Replacement.transaction do
        claimable = @outcome == "swapped" && (info[:valid] || @goodwill)
        r = Replacement.create!(customer: @customer, product: @product, invoice: info[:invoice], sold_on: info[:sold_on],
                                warranty_until: info[:warranty_until], warranty_valid: info[:valid], outcome: @outcome,
                                claim_status: claimable ? "awaiting" : "none", channel: @channel, defect: @defect,
                                serial_no: @serial, logged_by: Current.user, client_uuid: @uuid)
        if @outcome == "swapped"
          have = @product.stock("sellable")
          raise Error, "No #{@product.display_name} in sellable stock to swap" if have < 1
          StockMovement.post!([
            { product: @product, bucket: "awaiting_claim", quantity: 1, reason: "replacement_in", document: r, note: @defect },
            { product: @product, bucket: "sellable", quantity: -1, reason: "replacement_out", document: r }
          ])
        end
        r
      end
    end

    def self.lookup_on(invoice, product)
      until_date = invoice.invoice_date >> product.effective_warranty_months
      { invoice: invoice, sold_on: invoice.invoice_date, warranty_until: until_date, valid: Date.current <= until_date }
    end
  end
end
