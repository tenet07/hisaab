module Invoicing
  # Posts a GST invoice: one transaction writes the invoice, takes the pieces out of sellable stock,
  # and debits the customer. Then applies any advance/unallocated payments FIFO.
  class Post
    class Error < StandardError; end

    # items: [{ product:, quantity:, rate_paise: (nil = tier price), discount_pct: }]
    def self.call(**kw) = new(**kw).call

    # What the bill would total, without posting anything
    def self.estimate(customer:, items:, inclusive: nil) = new(customer: customer, items: items, inclusive: inclusive).calculator.total_paise

    def initialize(customer:, items:, date: Date.current, order: nil, channel: "counter", inclusive: nil,
                   allow_negative_stock: false, bill_to_name: nil)
      @customer, @items, @date, @order, @channel = customer, items, date.to_date, order, channel
      @inclusive = inclusive.nil? ? customer.prices_include_tax? : inclusive
      @allow_negative, @bill_to_name = allow_negative_stock, bill_to_name
    end

    def calculator
      shop = ShopSetting.current
      calc = Gst::Calculator.new(interstate: place_of_supply != shop.state_code, inclusive: @inclusive)
      @items.select { _1[:product] && _1[:quantity].to_i.positive? }.each do |i|
        calc.add(product: i[:product], quantity: i[:quantity],
                 rate_paise: i[:rate_paise] || i[:product].price_paise_for(@customer), discount_pct: i[:discount_pct] || 0)
      end
      calc
    end

    def place_of_supply = @customer.state_code.presence || ShopSetting.current.state_code

    def call
      items = @items.select { _1[:product] && _1[:quantity].to_i.positive? }
      raise Error, "Add at least one item" if items.empty?
      items.each do |i|
        raise Error, "Discount must be between 0 and 100%" unless (0..100).cover?(i[:discount_pct].to_d)
        raise Error, "Rate can't be negative" if i[:rate_paise].to_i.negative?
        raise Error, "Quantity for #{i[:product].display_name} is too large" if i[:quantity].to_i > 100_000
      end
      raise Error, "An invoice can't be dated in the future" if @date > Date.current
      shop = ShopSetting.current
      pos = place_of_supply
      calc = calculator
      raise Error, "The bill total must be above zero" unless calc.total_paise.positive?

      Invoice.transaction do
        check_stock!(calc.lines) unless @allow_negative
        number, fy = DocumentSequence.next!("invoice", @date)
        inv = Invoice.create!(
          number: number, fy: fy, customer: @customer, order: @order, invoice_date: @date,
          due_date: @date + shop.credit_days, channel: @channel, prices_include_tax: @inclusive,
          bill_to_name: @bill_to_name.presence || @customer.shop_name, bill_to_gstin: @customer.gstin,
          bill_to_address: @customer.address, place_of_supply: pos,
          taxable_paise: calc.taxable_paise, cgst_paise: calc.cgst_paise, sgst_paise: calc.sgst_paise,
          igst_paise: calc.igst_paise, round_off_paise: calc.round_off_paise, total_paise: calc.total_paise,
          eway_required: calc.total_paise > shop.eway_threshold_paise, posted_by: Current.user
        )
        calc.lines.each do |l|
          inv.lines.create!(l.to_h)
          StockMovement.create!(product: l.product, bucket: "sellable", quantity: -l.quantity, reason: "sale", document: inv)
        end
        LedgerEntry.create!(party: @customer, entry_date: @date, debit_paise: inv.total_paise, entry_type: "invoice",
                            document: inv, narration: "Invoice #{number}")
        @order&.update!(status: "invoiced")
        Payments::Allocate.call(@customer)
        EinvoiceJob.set(wait: 5.seconds).perform_later(inv.id) if Gst::Einvoice.applies?(inv)
        inv
      end
    end

    private

    def check_stock!(lines)
      lines.group_by(&:product).each do |product, ls|
        need = ls.sum(&:quantity)
        have = product.stock("sellable")
        raise Error, "Only #{have} #{product.unit} of #{product.display_name} in stock (bill needs #{need})" if have < need
      end
    end
  end
end
