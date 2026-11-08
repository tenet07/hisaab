require "test_helper"

class SuppliersTest < ActiveSupport::TestCase
  setup do
    setup_shop
    @phil = Supplier.create!(name: "Signify Dist", brands: "Philips , philips, Syska", credit_days: 30)
    @delhi = Supplier.create!(name: "Delhi Dist", gstin: "07AABCS5678E1Z3", brands: "Wipro")
  end

  def buy(qty: 50, rate: 6_050, number: "P1", supplier: @phil, printed: nil)
    Books.create_purchase(supplier: supplier, number: number, date: Date.current, user: @acct,
                          items: [{ product: @bulb, qty: qty, rate_paise: rate }], printed_total_paise: printed)
  end

  test "brands are cleaned and matched case-insensitively" do
    assert_equal %w[Philips Syska], @phil.brand_list
    assert_equal @phil, Supplier.for_brand("PHILIPS")
    assert_nil Supplier.for_brand("Havells")
  end

  test "purchase adds stock and what we owe, with GST" do
    bill = buy
    assert_equal 150, @bulb.stock
    assert_equal 302_500, bill.taxable_paise
    assert_equal 27_225, bill.cgst_paise
    assert_equal 357_000, bill.total_paise           # 3,569.50 rounded to the rupee
    assert_equal 50, bill.round_off_paise
    assert_equal 357_000, @phil.payable_paise
    assert_equal 7_139, @bulb.last_cost_paise
  end

  test "out-of-state supplier charges IGST" do
    bill = buy(supplier: @delhi)
    assert_equal 0, bill.cgst_paise
    assert bill.igst_paise.positive?
  end

  test "printed total mismatch and duplicate bills are refused, nothing posted" do
    assert_raises(Books::Error) { buy(printed: 350_000_00) }
    assert_equal 100, @bulb.stock
    buy(printed: 356_950) # within ₹1 of our total is accepted
    assert_raises(Books::Error) { buy }
    assert_equal 1, PurchaseBill.count
  end

  test "counter staff can't enter purchases; only owner/accounts pay" do
    counter = User.create!(name: "C", role: "counter", password: "1234")
    assert_raises(Books::Error) { Books.create_purchase(supplier: @phil, number: "X", date: Date.current, user: @sales, items: [{ product: @bulb, qty: 1, rate_paise: 1 }]) }
    assert_raises(Books::Error) { Books.pay_supplier(supplier: @phil, amount_paise: 100, mode: "cash", ref: nil, user: counter) }
    assert_raises(Books::Error) { Books.pay_supplier(supplier: @phil, amount_paise: 100, mode: "upi", ref: "", user: @acct) }
  end

  test "payments clear oldest bills and show what's due" do
    Books.supplier_opening(@phil, 50_000_00, user: @acct, date: Date.current - 60)
    bill = buy
    Books.pay_supplier(supplier: @phil, amount_paise: 51_000_00, mode: "upi", ref: "UTR9", user: @acct)
    unpaid = @phil.unpaid_bills
    assert_equal [bill], unpaid.map { _1[:bill] }
    assert_equal 357_000 - 1_000_00, unpaid.first[:due]
    assert_equal Date.current + 30, unpaid.first[:due_on]
  end

  test "an unpaid opening balance shows as the oldest, overdue item" do
    Books.supplier_opening(@phil, 85_000_00, user: @acct, date: Date.current - 40)
    buy
    first = @phil.unpaid_bills.first
    assert_equal "Opening balance", first[:ref]
    assert first[:due_on] < Date.current
    assert_equal 85_000_00 + 357_000, @phil.unpaid_bills.sum { _1[:due] }
  end

  test "claim credit note reduces what we owe the brand" do
    buy
    Books.replace(customer: @shop, product: @bulb, qty: 4, user: @sales, sold_on: Date.current - 20)
    claim = Books.send_claim(brand: "Philips", user: @acct)
    assert_equal @phil, claim.supplier
    assert_raises(Books::Error) { Books.record_claim_credit(claim: claim, number: "CN1", amount_paise: 100, user: @acct) }
    Books.settle_claim_line(claim.lines.first, new_qty: 1, credit_qty: 3, rejected_qty: 0, user: @acct)
    assert_equal 3 * 7_139, claim.reload.expected_credit_paise
    assert_raises(Books::Error) { Books.record_claim_credit(claim: claim, number: "CN1", amount_paise: 100, user: @sales) }
    Books.record_claim_credit(claim: claim, number: "SIG-CN-77", amount_paise: 21_000, user: @acct)
    assert_equal 357_000 - 21_000, @phil.payable_paise
    assert_equal 21_000, claim.reload.credited_paise
  end
end
