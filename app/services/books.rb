# The only code that writes stock movements and ledger entries.
# Every operation runs in one transaction: all of it posts, or none of it.
module Books
  class Error < StandardError; end
  module_function

  # ------------------------------------------------------------ stock
  # moves: [[product, bucket, qty], ...]
  def post_stock(moves, reason:, ref:, user:)
    raise Error, "every movement needs a user" unless user
    ids = moves.map { |p, _, _| p.id }.uniq
    Product.where(id: ids).lock.to_a # serialise concurrent postings on these products

    after = Hash.new { |h, (pid, b)| h[[pid, b]] = StockMovement.where(product_id: pid, bucket: b.to_s).sum(:qty) }
    moves.each { |p, b, q| after[[p.id, b]] += q }
    if (bad = after.find { |_, v| v.negative? })
      prod = Product.find(bad[0][0])
      raise Error, "Not enough #{prod.label} in #{bad[0][1].to_s.tr('_', ' ')} (would be #{bad[1]})"
    end
    moves.each do |p, b, q|
      StockMovement.create!(product: p, bucket: b.to_s, qty: q, reason: reason, ref: ref, user: user)
    end
  end

  def opening_stock(product, qty, user:)
    ApplicationRecord.transaction { post_stock([[product, :sellable, qty]], reason: "opening", ref: nil, user: user) }
  end

  def purchase(product, qty, ref:, user:)
    raise Error, "quantity must be positive" unless qty.positive?
    ApplicationRecord.transaction { post_stock([[product, :sellable, qty]], reason: "purchase", ref: ref, user: user) }
  end

  def count_adjustment(product, counted:, reason:, user:)
    raise Error, "an adjustment needs a reason" if reason.to_s.strip.empty?
    ApplicationRecord.transaction do
      diff = counted - product.stock
      next 0 if diff.zero?
      post_stock([[product, :sellable, diff]], reason: "adjustment: #{reason.strip}", ref: nil, user: user)
      diff
    end
  end

  # --------------------------------------------------------- invoices
  # items: [{product:, qty:, discount_paise:}]
  def create_invoice(customer:, items:, user:, date: Date.current, channel: "counter", deliver: nil)
    deliver = customer.price_tier == "wholesale" if deliver.nil?
    items = items.select { |i| i[:qty].to_i.positive? }
    raise Error, "add at least one item" if items.empty?

    core_lines = items.map do |i|
      p = i[:product]
      Shop::Line.new(sku: p.sku, name: p.name, hsn: p.hsn, qty: i[:qty].to_i,
                     unit_price_paise: p.price_for(customer), gst_bp: p.gst_bp,
                     discount_paise: i[:discount_paise].to_i, price_includes_tax: p.price_includes_tax)
    end

    ApplicationRecord.transaction do
      number = Invoice.next_number(date)
      core = Shop::Invoice.new(number: number, date: date, customer_id: customer.id,
                               lines: core_lines, intra_state: customer.intra_state?)
      inv = Invoice.create!(number: number, date: date, customer: customer, intra_state: core.intra_state,
                            taxable_paise: core.taxable, cgst_paise: core.cgst, sgst_paise: core.sgst,
                            igst_paise: core.igst, round_off_paise: core.round_off,
                            total_paise: core.total, channel: channel, created_by: user,
                            seller: Invoice.seller_snapshot, buyer: Invoice.buyer_snapshot(customer))
      core.lines.zip(items).each do |t, i|
        inv.lines.create!(product: i[:product], qty: t.line.qty, unit_price_paise: t.line.unit_price_paise,
                          discount_paise: t.line.discount_paise, gst_bp: t.line.gst_bp,
                          price_includes_tax: t.line.price_includes_tax,
                          taxable_paise: t.taxable, tax_paise: t.tax)
      end
      post_stock(items.map { |i| [i[:product], :sellable, -i[:qty].to_i] }, reason: "sale", ref: number, user: user)
      LedgerEntry.create!(customer: customer, date: date, kind: "invoice", ref: number,
                          debit_paise: core.total, user: user)
      create_delivery(inv, run_date: next_delivery_date(customer.market, date)) if deliver
      inv
    end
  end

  # Cancelling never deletes: it posts reversing stock and ledger entries.
  def cancel_invoice(invoice, user:, reason:)
    raise Error, "only the owner or accounts can cancel a bill" unless %w[owner accounts].include?(user.role)
    raise Error, "already cancelled" if invoice.cancelled?
    raise Error, "give a reason" if reason.to_s.strip.empty?
    if invoice.delivery&.done? || invoice.credit_notes.any?
      raise Error, "Goods already delivered. Take the goods back as a return instead of cancelling."
    end
    ApplicationRecord.transaction do
      invoice.delivery&.update!(status: "cancelled")
      post_stock(invoice.lines.map { |l| [l.product, :sellable, l.qty] },
                 reason: "cancel: #{reason.strip}", ref: invoice.number, user: user)
      LedgerEntry.create!(customer: invoice.customer, date: Date.current, kind: "invoice_cancelled",
                          ref: invoice.number, credit_paise: invoice.total_paise, user: user)
      invoice.update!(status: "cancelled")
    end
  end

  # --------------------------------------------------------- payments
  def record_payment(customer:, amount_paise:, mode:, user:, ref: nil, note: nil, date: Date.current, delivery: nil)
    raise Error, "amount must be positive" unless amount_paise.to_i.positive?
    ApplicationRecord.transaction do
      ref = ref.presence || "RC/#{Time.current.strftime('%y%m%d%H%M%S')}/#{user.id}"
      pay = Payment.create!(customer: customer, date: date, amount_paise: amount_paise, mode: mode,
                            ref: ref, note: note, user: user, delivery: delivery)
      LedgerEntry.create!(customer: customer, date: date, kind: "payment_#{mode}", ref: ref,
                          credit_paise: amount_paise, user: user)
      pay
    end
  end

  def opening_balance(customer, amount_paise, user:, date: Date.current)
    LedgerEntry.create!(customer: customer, date: date, kind: "opening", ref: "OPENING",
                        debit_paise: [amount_paise, 0].max, credit_paise: [-amount_paise, 0].max, user: user)
  end

  # ----------------------------------------------------- replacements
  def replace(customer:, product:, qty:, user:, sold_on: nil, invoice_number: nil, note: nil, override: false)
    in_warranty = sold_on.present? &&
                  Shop::Warranty.valid?(sold_on: sold_on, warranty_months: product.warranty_months, today: Date.current)
    if !in_warranty && !(override && user.owner?)
      raise Error, "Out of warranty (or no sale date). Only the owner can approve a free swap."
    end
    ApplicationRecord.transaction do
      r = Replacement.create!(customer: customer, product: product, qty: qty, sold_on: sold_on,
                              invoice_number: invoice_number, in_warranty: in_warranty, note: note, user: user)
      post_stock([[product, :sellable, -qty], [product, :awaiting_claim, qty]],
                 reason: "replacement", ref: "RPL-#{r.id}", user: user)
      r
    end
  end

  # Batch everything awaiting claim for a brand into one claim.
  def send_claim(brand:, user:)
    products = Product.where(brand: brand).select { |p| p.stock(:awaiting_claim).positive? }
    raise Error, "nothing awaiting claim for #{brand}" if products.empty?
    ApplicationRecord.transaction do
      claim = Claim.create!(number: "CLM-#{brand.parameterize.upcase.first(6)}-#{Time.current.strftime('%y%m%d%H%M')}",
                            brand: brand, sent_on: Date.current, user: user, supplier: Supplier.for_brand(brand))
      moves = products.flat_map do |p|
        q = p.stock(:awaiting_claim)
        claim.lines.create!(product: p, qty: q)
        [[p, :awaiting_claim, -q], [p, :with_brand, q]]
      end
      post_stock(moves, reason: "claim_sent", ref: claim.number, user: user)
      claim
    end
  end

  def settle_claim_line(line, new_qty:, credit_qty:, rejected_qty:, user:)
    new_qty, credit_qty, rejected_qty = [new_qty, credit_qty, rejected_qty].map(&:to_i)
    total = new_qty + credit_qty + rejected_qty
    raise Error, "nothing to settle" unless total.positive?
    raise Error, "only #{line.open_qty} still open on this line" if total > line.open_qty
    raise Error, "only the owner can approve a write-off" if rejected_qty.positive? && !user.owner?

    ApplicationRecord.transaction do
      p = line.product
      moves = [[p, :with_brand, -total]]
      moves << [p, :sellable, new_qty] if new_qty.positive?
      moves << [p, :written_off, rejected_qty] if rejected_qty.positive?
      post_stock(moves, reason: "claim_settled", ref: line.claim.number, user: user)
      line.update!(settled_new_qty: line.settled_new_qty + new_qty,
                   settled_credit_qty: line.settled_credit_qty + credit_qty,
                   rejected_qty: line.rejected_qty + rejected_qty)
      claim = line.claim
      claim.update!(status: claim.reload.open_qty.zero? ? "closed" : "partly settled")
    end
  end

  # -------------------------------------------------------- deliveries
  DAYS = %w[Sun Mon Tue Wed Thu Fri Sat].freeze

  # The market's next delivery day on or after the bill date.
  def next_delivery_date(market, from)
    idx = DAYS.index(market&.delivery_day)
    return from unless idx
    from + ((idx - from.wday) % 7)
  end

  def create_delivery(invoice, run_date:)
    d = Delivery.create!(invoice: invoice, run_date: run_date, otp: Delivery.new_otp,
                         assigned_to: invoice.customer.market&.delivery_person)
    invoice.lines.each { |l| d.items.create!(invoice_line: l) }
    d
  end

  def assign_delivery(delivery, to:, run_date:, user:)
    raise Error, "only the office can plan deliveries" unless user.office?
    raise Error, "this delivery is already #{delivery.status.humanize.downcase}" unless delivery.open?
    raise Error, "#{to.name} is not delivery staff" if to && !to.delivery?
    delivery.update!(assigned_to: to, run_date: run_date)
  end

  # Delivery person ticks what actually went into the vehicle.
  def load_delivery(delivery, loaded:, user:)
    raise Error, "already #{delivery.status.humanize.downcase}" unless delivery.status == "pending"
    ApplicationRecord.transaction do
      delivery.items.each do |i|
        q = loaded.fetch(i.id.to_s, loaded.fetch(i.id, i.qty)).to_i
        raise Error, "#{i.product.name}: loaded #{q} but bill has #{i.qty}" if q.negative? || q > i.qty
        i.update!(loaded_qty: q)
      end
      delivery.update!(status: "loaded", loaded_at: Time.current, assigned_to: delivery.assigned_to || user)
    end
  end

  # delivered: {item_id => qty}; reasons: {item_id => text}
  # Proof: the customer's 4-digit code, or a photo of the goods at the shop.
  # damaged: {item_id => qty} of the short pieces that are broken (written off, not reshelved)
  def complete_delivery(delivery, delivered:, user:, reasons: {}, damaged: {}, otp: nil, photo: nil,
                        cash_paise: 0, cash_mode: "cash")
    raise Error, "already #{delivery.status.humanize.downcase}" unless delivery.open?
    proof = if otp.present?
      raise Error, "Wrong delivery code. Ask the customer to check the bill message." unless otp.to_s.strip == delivery.otp
      "otp"
    elsif photo
      raise Error, "Photo too large (max 3 MB)" if photo[:data].bytesize > 3.megabytes
      "photo"
    else
      raise Error, "Enter the customer's delivery code or take a photo"
    end

    ApplicationRecord.transaction do
      shorts = []
      delivery.items.includes(invoice_line: :product).each do |i|
        cap = i.loaded_qty || i.qty
        q = delivered.fetch(i.id.to_s, delivered.fetch(i.id, cap)).to_i
        raise Error, "#{i.product.name}: delivered #{q} but only #{cap} on the vehicle" if q.negative? || q > cap
        reason = reasons[i.id.to_s].presence || reasons[i.id].presence
        raise Error, "#{i.product.name}: say why #{i.qty - q} short" if q < i.qty && reason.blank?
        dmg = (damaged[i.id.to_s] || damaged[i.id]).to_i
        raise Error, "#{i.product.name}: #{dmg} damaged but only #{i.qty - q} short" if dmg.negative? || dmg > i.qty - q
        i.update!(delivered_qty: q, short_reason: (reason if q < i.qty))
        i.damaged_qty = dmg
        shorts << i if q < i.qty
      end
      raise Error, "Nothing delivered: mark this stop as failed instead" if delivery.items.sum(:delivered_qty).zero?

      credit_short_items(delivery, shorts, user: user) if shorts.any?
      if cash_paise.to_i.positive?
        record_payment(customer: delivery.customer, amount_paise: cash_paise.to_i, mode: cash_mode,
                       user: user, delivery: delivery, note: "on delivery")
      end
      delivery.update!(status: shorts.any? ? "partly_delivered" : "delivered", delivered_at: Time.current,
                       proof_kind: proof, photo_data: photo&.dig(:data), photo_type: photo&.dig(:type),
                       attempts: delivery.attempts + 1, assigned_to: delivery.assigned_to || user)
    end
  end

  # Shop closed, owner absent, refused: goods stay in the shop, bill stands.
  def fail_delivery(delivery, reason:, user:)
    raise Error, "already #{delivery.status.humanize.downcase}" unless delivery.open?
    raise Error, "say why it couldn't be delivered" if reason.to_s.strip.empty?
    delivery.items.update_all(loaded_qty: nil)
    delivery.update!(status: "failed", note: reason.strip, attempts: delivery.attempts + 1)
  end

  def reschedule_delivery(delivery, run_date:, user:)
    raise Error, "only failed deliveries can be rescheduled" unless delivery.status == "failed"
    raise Error, "only the office can reschedule" unless user.office?
    delivery.update!(status: "pending", run_date: run_date, loaded_at: nil)
  end

  # Undelivered pieces come back to the shelf and the customer is credited
  # for them with GST reversed line by line.
  def credit_short_items(delivery, shorts, user:)
    inv = delivery.invoice
    taxed = shorts.map do |i|
      l = i.invoice_line
      short = l.qty - i.delivered_qty
      Shop::GST.tax_line(
        Shop::Line.new(sku: l.product.sku, name: l.product.name, hsn: l.product.hsn, qty: short,
                       unit_price_paise: l.unit_price_paise, gst_bp: l.gst_bp,
                       discount_paise: Shop::Money.div_round(l.discount_paise * short, l.qty),
                       price_includes_tax: l.price_includes_tax),
        intra_state: inv.intra_state)
    end
    taxable, cgst, sgst, igst = %i[taxable cgst sgst igst].map { |k| taxed.sum(&k) }
    total = taxable + cgst + sgst + igst
    date = Date.current
    cn = CreditNote.create!(number: CreditNote.next_number(date), date: date, invoice: inv, customer: inv.customer,
                            delivery: delivery, user: user, taxable_paise: taxable, cgst_paise: cgst,
                            sgst_paise: sgst, igst_paise: igst, total_paise: total,
                            reason: "Not delivered: " + shorts.map { |i| "#{i.product.name} × #{i.short_qty} (#{i.short_reason})" }.join("; "))
    LedgerEntry.create!(customer: inv.customer, date: date, kind: "credit_note", ref: cn.number,
                        credit_paise: total, user: user)
    moves = shorts.flat_map do |i|
      dmg = i.damaged_qty.to_i
      [([i.product, :sellable, i.short_qty - dmg] if i.short_qty > dmg),
       ([i.product, :written_off, dmg] if dmg.positive?)].compact
    end
    post_stock(moves, reason: "delivery_short", ref: cn.number, user: user)
    cn
  end

  # --------------------------------------------------------- suppliers
  # items: [{product:, qty:, rate_paise:, discount_paise:}]; rates are before GST.
  # printed_total_paise: the total on the supplier's bill, to catch typing mistakes.
  def create_purchase(supplier:, number:, date:, items:, user:, printed_total_paise: nil)
    raise Error, "only the office can enter purchases" unless user.office?
    raise Error, "enter the supplier's bill number" if number.to_s.strip.empty?
    items = items.select { |i| i[:qty].to_i.positive? }
    raise Error, "add at least one item" if items.empty?
    if PurchaseBill.exists?(supplier: supplier, number: number.strip)
      raise Error, "Bill #{number} from #{supplier.name} is already entered"
    end
    items.each { |i| raise Error, "#{i[:product].label}: enter the rate" unless i[:rate_paise].to_i.positive? }

    core = Shop::Invoice.new(number: number.strip, date: date, customer_id: supplier.id, intra_state: supplier.intra_state?,
      lines: items.map { |i|
        p = i[:product]
        Shop::Line.new(sku: p.sku, name: p.name, hsn: p.hsn, qty: i[:qty].to_i, unit_price_paise: i[:rate_paise].to_i,
                       gst_bp: p.gst_bp, discount_paise: i[:discount_paise].to_i, price_includes_tax: false)
      })
    if printed_total_paise.to_i.positive? && (printed_total_paise.to_i - core.total).abs > 100
      raise Error, "Our total #{Shop::Money.format(core.total)} doesn't match the bill's " \
                   "#{Shop::Money.format(printed_total_paise.to_i)}. Check quantities, rates and GST."
    end

    ApplicationRecord.transaction do
      bill = PurchaseBill.create!(supplier: supplier, number: core.number, date: date, intra_state: core.intra_state,
                                  taxable_paise: core.taxable, cgst_paise: core.cgst, sgst_paise: core.sgst,
                                  igst_paise: core.igst, round_off_paise: core.round_off, total_paise: core.total, user: user)
      core.lines.zip(items).each do |t, i|
        bill.lines.create!(product: i[:product], qty: t.line.qty, rate_paise: t.line.unit_price_paise,
                           discount_paise: t.line.discount_paise, gst_bp: t.line.gst_bp,
                           taxable_paise: t.taxable, tax_paise: t.tax)
      end
      post_stock(items.map { |i| [i[:product], :sellable, i[:qty].to_i] }, reason: "purchase",
                 ref: "#{supplier.name}/#{core.number}", user: user)
      SupplierEntry.create!(supplier: supplier, date: date, kind: "purchase", ref: core.number,
                            credit_paise: core.total, user: user)
      bill
    end
  end

  def supplier_opening(supplier, amount_paise, user:, date: Date.current)
    SupplierEntry.create!(supplier: supplier, date: date, kind: "opening", ref: "OPENING",
                          credit_paise: [amount_paise, 0].max, debit_paise: [-amount_paise, 0].max, user: user)
  end

  def pay_supplier(supplier:, amount_paise:, mode:, ref:, user:, date: Date.current)
    raise Error, "only owner or accounts can pay suppliers" unless %w[owner accounts].include?(user.role)
    raise Error, "amount must be positive" unless amount_paise.to_i.positive?
    raise Error, "mode must be cash, UPI or cheque" unless Payment::MODES.include?(mode)
    raise Error, "enter the UPI / cheque / bank reference" if mode != "cash" && ref.to_s.strip.empty?
    ApplicationRecord.transaction do
      ref = ref.presence || "PAY/#{Time.current.strftime('%y%m%d%H%M%S')}"
      pay = SupplierPayment.create!(supplier: supplier, date: date, amount_paise: amount_paise, mode: mode, ref: ref, user: user)
      SupplierEntry.create!(supplier: supplier, date: date, kind: "payment_#{mode}", ref: ref,
                            debit_paise: amount_paise, user: user)
      pay
    end
  end

  # The brand's credit note for pieces accepted on a claim: reduces what we owe them.
  def record_claim_credit(claim:, number:, amount_paise:, user:, date: Date.current)
    raise Error, "only owner or accounts can record brand credit notes" unless %w[owner accounts].include?(user.role)
    raise Error, "amount must be positive" unless amount_paise.to_i.positive?
    raise Error, "enter the brand's credit note number" if number.to_s.strip.empty?
    supplier = claim.supplier || Supplier.for_brand(claim.brand)
    raise Error, "No supplier handles #{claim.brand}. Add the brand to a supplier first." unless supplier
    raise Error, "Mark pieces as 'credit note' on this claim first" unless claim.credit_qty.positive?
    ApplicationRecord.transaction do
      claim.update!(supplier: supplier) unless claim.supplier
      cc = ClaimCredit.create!(claim: claim, supplier: supplier, number: number.strip, date: date,
                               amount_paise: amount_paise, user: user)
      SupplierEntry.create!(supplier: supplier, date: date, kind: "claim_credit", ref: number.strip,
                            debit_paise: amount_paise, note: claim.number, user: user)
      cc
    end
  end
end
