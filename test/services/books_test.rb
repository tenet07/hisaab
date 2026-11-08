require "test_helper"

class BooksTest < ActiveSupport::TestCase
  setup { setup_shop }

  test "invoice posts stock, ledger and GST together" do
    inv = Books.create_invoice(customer: @shop, user: @acct, items: [{ product: @bulb, qty: 10 }])
    assert_equal 90, @bulb.stock
    assert_equal 62_000, inv.taxable_paise
    assert_equal 5_580, inv.cgst_paise
    assert_equal 5_580, inv.sgst_paise
    assert_equal 73_200, inv.total_paise # 73160 rounded to ₹732
    assert_equal inv.total_paise, @shop.balance_paise
    assert_equal inv.total_paise, inv.to_core.total
    assert_match %r{\AINV/\d\d-\d\d/00001\z}, inv.number
  end

  test "out-of-state customer gets IGST" do
    inv = Books.create_invoice(customer: @far, user: @acct, items: [{ product: @bulb, qty: 1 }])
    assert_equal 0, inv.cgst_paise
    assert inv.igst_paise.positive?
  end

  test "overselling posts nothing at all" do
    assert_raises(Books::Error) { Books.create_invoice(customer: @shop, user: @acct, items: [{ product: @bulb, qty: 101 }]) }
    assert_equal 0, Invoice.count
    assert_equal 0, @shop.balance_paise
    assert_equal 100, @bulb.stock
  end

  test "invoice numbers run in sequence" do
    a = Books.create_invoice(customer: @shop, user: @acct, items: [{ product: @bulb, qty: 1 }])
    b = Books.create_invoice(customer: @shop, user: @acct, items: [{ product: @bulb, qty: 1 }])
    assert_equal a.number.sub(/00001\z/, "00002"), b.number
  end

  test "cancelling reverses stock and balance, never deletes" do
    inv = Books.create_invoice(customer: @shop, user: @acct, items: [{ product: @bulb, qty: 10 }])
    assert_raises(Books::Error) { Books.cancel_invoice(inv, user: @sales, reason: "x") }
    Books.cancel_invoice(inv, user: @acct, reason: "wrong customer")
    assert_equal 100, @bulb.stock
    assert_equal 0, @shop.balance_paise
    assert_equal 2, @shop.ledger_entries.count
  end

  test "payments reduce balance and settle oldest bill first" do
    Books.opening_balance(@shop, 50_000, user: @acct, date: Date.current - 60)
    Books.create_invoice(customer: @shop, user: @acct, items: [{ product: @bulb, qty: 10 }])
    Books.record_payment(customer: @shop, amount_paise: 60_000, mode: "upi", ref: "U1", user: @sales)
    open = @shop.open_items
    assert_equal 1, open.size
    assert_equal 63_200, open.first[:due]
  end

  test "ledger and stock rows are append-only" do
    Books.record_payment(customer: @shop, amount_paise: 100, mode: "cash", user: @sales)
    assert_raises(ActiveRecord::ReadOnlyRecord) { LedgerEntry.last.update!(credit_paise: 1) }
    assert_raises(ActiveRecord::ReadOnlyRecord) { StockMovement.last.destroy }
  end

  test "replacement in warranty moves defective to awaiting claim" do
    Books.replace(customer: @shop, product: @bulb, qty: 2, user: @sales, sold_on: Date.current - 30)
    assert_equal({ sellable: 98, awaiting_claim: 2, with_brand: 0, written_off: 0 }, @bulb.snapshot)
  end

  test "out of warranty needs owner approval" do
    assert_raises(Books::Error) { Books.replace(customer: @shop, product: @bulb, qty: 1, user: @sales, sold_on: Date.current - 400) }
    assert_raises(Books::Error) { Books.replace(customer: @shop, product: @bulb, qty: 1, user: @sales, sold_on: Date.current - 400, override: true) }
    r = Books.replace(customer: @shop, product: @bulb, qty: 1, user: @owner, sold_on: Date.current - 400, override: true)
    refute r.in_warranty
  end

  test "claim lifecycle keeps every piece accounted for" do
    Books.replace(customer: @shop, product: @bulb, qty: 5, user: @sales, sold_on: Date.current - 10)
    claim = Books.send_claim(brand: "Philips", user: @acct)
    line = claim.lines.first
    assert_equal 5, @bulb.stock(:with_brand)
    Books.settle_claim_line(line, new_qty: 2, credit_qty: 2, rejected_qty: 0, user: @acct)
    assert_raises(Books::Error) { Books.settle_claim_line(line.reload, new_qty: 0, credit_qty: 0, rejected_qty: 1, user: @acct) }
    assert_raises(Books::Error) { Books.settle_claim_line(line.reload, new_qty: 2, credit_qty: 0, rejected_qty: 0, user: @acct) }
    Books.settle_claim_line(line.reload, new_qty: 0, credit_qty: 0, rejected_qty: 1, user: @owner)
    assert_equal({ sellable: 97, awaiting_claim: 0, with_brand: 0, written_off: 1 }, @bulb.snapshot)
    assert_equal "closed", claim.reload.status
  end

  test "count adjustment posts the difference with a reason" do
    assert_raises(Books::Error) { Books.count_adjustment(@bulb, counted: 95, reason: "", user: @owner) }
    assert_equal(-5, Books.count_adjustment(@bulb, counted: 95, reason: "breakage", user: @owner))
    assert_equal 95, @bulb.stock
  end

  test "a bill keeps the shop and customer details it was issued with" do
    ShopSetting.current.update!(name: "Old Name", gstin: "06ABCPS1234F1Z5")
    inv = Books.create_invoice(customer: @shop, user: @acct, items: [{ product: @bulb, qty: 1 }])
    ShopSetting.current.update!(name: "New Name")
    @shop.update!(name: "Gupta Renamed", address: "New address")
    inv.reload
    assert_equal "Old Name", inv.seller_details[:name]
    assert_equal "Gupta", inv.buyer_details[:name]
    assert_equal "06", inv.place_of_supply
  end

  test "HSN tax summary adds up to the bill" do
    tube = Product.create!(sku: "T", name: "Tube", brand: "Philips", hsn: "9405", gst_bp: 1200,
                           retail_price_paise: 30_000, wholesale_price_paise: 19_999)
    Books.opening_stock(tube, 10, user: @acct)
    inv = Books.create_invoice(customer: @shop, user: @acct, items: [{ product: @bulb, qty: 3 }, { product: tube, qty: 7 }])
    rows = inv.hsn_tax_summary
    assert_equal %w[8539 9405], rows.map { _1[:hsn] }
    assert_equal inv.cgst_paise, rows.sum { _1[:cgst] }
    assert_equal inv.sgst_paise, rows.sum { _1[:sgst] }
    assert_equal inv.taxable_paise, rows.sum { _1[:taxable] }
  end
end
