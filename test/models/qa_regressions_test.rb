require "test_helper"

# One test per QA finding that touched money or stock (see QA_REPORT.md).
class QaRegressionsTest < ActiveSupport::TestCase
  setup { build_shop }

  test "C2: payments clear an opening balance first and dues include it" do
    OpeningBalance.post!(@cust, 500_000)
    Payments::Record.call(customer: @cust, amount_paise: 100_000, mode: "cash")
    inv = bill(@cust, [{ product: @bulb, quantity: 10 }])
    assert_equal inv.total_paise, inv.reload.outstanding_paise
    assert_equal 400_000 + inv.total_paise, @cust.balance_paise
    assert_equal @cust.balance_paise, @cust.open_items.sum(&:outstanding_paise)
    assert_equal 0, @cust.unallocated_paise
    assert_equal "Opening balance", @cust.oldest_unpaid.number
  end

  test "C2: an opening advance pays the next bill" do
    OpeningBalance.post!(@cust, -100_000)
    inv = bill(@cust, [{ product: @bulb, quantity: 10 }])
    assert_equal 0, inv.reload.outstanding_paise
    assert_equal @cust.balance_paise, -@cust.unallocated_paise + @cust.open_items.sum(&:outstanding_paise)
  end

  test "C3: a dealer pays the same price at the counter and on the invoice screen" do
    dealer = Customer.create!(shop_name: "Unregistered Dealer", phone: "9820099999", price_tier: "wholesale")
    a = bill(dealer, [{ product: @bulb, quantity: 10 }])
    b = Invoicing::Post.call(customer: dealer, items: [{ product: @bulb, quantity: 10 }], channel: "counter")
    assert_equal a.total_paise, b.total_paise
    assert_equal a.total_paise, Invoicing::Post.estimate(customer: dealer, items: [{ product: @bulb, quantity: 10 }])
  end

  test "H1: quoting someone else's invoice doesn't grant warranty" do
    other = Customer.create!(shop_name: "Other", phone: "9820077777")
    inv = bill(other, [{ product: @bulb, quantity: 1 }])
    assert_raises(Replacements::Intake::Error) do
      Replacements::Intake.call(customer: @cust, product: @bulb, outcome: "swapped", invoice: inv)
    end
  end

  test "H2: a piece with a pending write-off can't be claimed, and a claimed piece can't be written off" do
    bill(@cust, [{ product: @bulb, quantity: 5 }], date: Date.current - 10)
    a, b = 2.times.map { Replacements::Intake.call(customer: @cust, product: @bulb, outcome: "swapped") }
    approval = Replacements::WriteOff.request!(a, reason: "burnt")
    claim = Claims::Batch.build(@brand, [a, b])
    assert_equal [b], claim.replacements.to_a
    Claims::Batch.dispatch!(claim, challan_no: "X")
    other = (Replacements::WriteOff.request!(b.reload, reason: "x") rescue nil) # b is with the brand now
    Approvals.decide!(approval, approve: true)
    assert_equal 0, @bulb.stock("awaiting_claim")
    assert_equal 1, @bulb.stock("with_brand")
    assert_equal 1, @bulb.stock("written_off")
    assert_nil other
  end

  test "H5: a failed delivery can be put on another route" do
    inv = bill
    run = DispatchRun.create!(market: @market, run_date: Date.current, status: "out")
    d = run.deliveries.create!(invoice: inv)
    Dispatch::Drop.complete!(d, failed_reason: "Shop closed")
    assert_includes Invoice.undispatched, inv
    assert run.reload.status == "done"
  end

  test "H6: a full return reverses the invoice to the paisa" do
    inv = bill(@cust, [{ product: @bulb, quantity: 3, rate_paise: 6033, discount_pct: 3.3 }, { product: @batten, quantity: 7, rate_paise: 23_917 }])
    refute_equal 0, inv.round_off_paise
    Invoicing::CreditNote.call(invoice: inv, reason: "return", items: [{ invoice_line: inv.lines.first, quantity: 1 }])
    Invoicing::CreditNote.call(invoice: inv, reason: "return", items: inv.lines.map { { invoice_line: _1, quantity: _1.quantity - (_1 == inv.lines.first ? 1 : 0) } })
    assert_equal inv.total_paise, inv.credit_notes.sum(:total_paise)
    assert_equal 0, inv.reload.outstanding_paise
    assert_equal 0, @cust.balance_paise
    assert_equal 500, @bulb.stock
  end

  test "M3: a rate-difference credit can't exceed the line's net rate" do
    inv = bill
    assert_raises(Invoicing::CreditNote::Error) do
      Invoicing::CreditNote.call(invoice: inv, reason: "rate_difference", items: [{ invoice_line: inv.lines.first, quantity: 2, rate_paise: 100_000 }])
    end
  end

  test "H7: a counter cash payment settles the bill it was paid for" do
    old = bill(@cust, [{ product: @bulb, quantity: 1 }], date: Date.current - 3)
    inv = bill(@cust, [{ product: @bulb, quantity: 2 }])
    Payments::Record.call(customer: @cust, amount_paise: inv.total_paise, mode: "cash", apply_to: inv)
    assert_equal 0, inv.reload.outstanding_paise
    assert_equal old.total_paise, old.reload.outstanding_paise
  end

  test "H11: invoices from a filed period can't be cancelled" do
    refute Invoicing::Cancel.cancellable_period?(Date.new(2026, 8, 20), Date.new(2026, 10, 20))
    assert Invoicing::Cancel.cancellable_period?(Date.new(2026, 9, 20), Date.new(2026, 10, 5))
    refute Invoicing::Cancel.cancellable_period?(Date.new(2026, 9, 20), Date.new(2026, 10, 15))
  end

  test "H12: B2C credit notes are netted in GSTR-1 so it agrees with 3B" do
    walk = Customer.create!(shop_name: "Cash", phone: "9100000000", price_tier: "retail")
    inv = bill(walk, [{ product: @bulb, quantity: 5 }])
    Invoicing::CreditNote.call(invoice: inv, reason: "return", items: [{ invoice_line: inv.lines.first, quantity: 2 }])
    g1 = Reports::Gstr1.new(Date.current)
    assert_equal Reports::Gstr3b.new(Date.current).outward[:taxable], g1.b2cs.sum { _1[:taxable] } + g1.b2b.sum(&:taxable_paise)
  end

  test "M9: no future-dated bills or payments" do
    assert_raises(Invoicing::Post::Error) { bill(@cust, [{ product: @bulb, quantity: 1 }], date: Date.current + 1) }
    assert_raises(Payments::Record::Error) { Payments::Record.call(customer: @cust, amount_paise: 100, mode: "cash", received_on: Date.current + 1) }
  end

  test "M4: discounts outside 0–100% are refused" do
    assert_raises(Invoicing::Post::Error) { bill(@cust, [{ product: @bulb, quantity: 1, discount_pct: -50 }]) }
    assert_raises(Invoicing::Post::Error) { bill(@cust, [{ product: @bulb, quantity: 1, discount_pct: 150 }]) }
  end

  test "M10: chatter with numbers doesn't become an order; dozens multiply" do
    assert_nil Whatsapp::Inbound.handle(phone: @cust.phone, text: "payment kar diya 5000").document
    assert_equal 0, Order.count
    assert_equal 24, OrderParser::Fuzzy.parse("philips 9w 2 dozen").first.quantity
  end

  test "L7: OTP attempts are limited" do
    inv = bill
    d = DispatchRun.create!(market: @market, run_date: Date.current, status: "out").deliveries.create!(invoice: inv)
    5.times { assert_raises(Dispatch::Drop::Error) { Dispatch::Drop.complete!(d, otp: "x") } }
    e = assert_raises(Dispatch::Drop::Error) { Dispatch::Drop.complete!(d.reload, otp: d.otp_code) }
    assert_match "photo", e.message
  end
end
