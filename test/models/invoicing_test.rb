require "test_helper"

class InvoicingTest < ActiveSupport::TestCase
  setup { build_shop }

  test "intra-state invoice splits CGST and SGST and rounds to the rupee" do
    inv = bill(@cust, [{ product: @bulb, quantity: 3, rate_paise: 6033 }])
    assert_equal 18099, inv.taxable_paise
    assert_equal 2172, inv.cgst_paise + inv.sgst_paise
    assert_equal 1086, inv.cgst_paise
    assert_equal 0, inv.igst_paise
    assert_equal 0, inv.total_paise % 100
    assert_equal inv.taxable_paise + inv.cgst_paise + inv.sgst_paise + inv.round_off_paise, inv.total_paise
  end

  test "inter-state invoice uses IGST" do
    gj = Customer.create!(shop_name: "Surat Mart", phone: "9825011122", gstin: Gstin.with_checksum("24AAHCS4321K1Z"))
    inv = bill(gj, [{ product: @batten, quantity: 2 }])
    assert_equal "24", inv.place_of_supply
    assert_equal 0, inv.cgst_paise
    assert_equal (48000 * 0.18).round, inv.igst_paise
  end

  test "counter B2C prices include tax" do
    walk = Customer.create!(shop_name: "Cash", phone: "9100000000", price_tier: "retail")
    inv = bill(walk, [{ product: @bulb, quantity: 1 }], inclusive: true)
    assert_equal 10000, inv.total_paise
    assert_equal 8929, inv.taxable_paise
  end

  test "serials run per financial year" do
    a = bill(@cust, [{ product: @bulb, quantity: 1 }], date: Date.new(2026, 3, 31))
    b = bill(@cust, [{ product: @bulb, quantity: 1 }], date: Date.new(2026, 4, 1))
    assert_match %r{/2025-26/00001\z}, a.number
    assert_match %r{/2026-27/00001\z}, b.number
  end

  test "cannot bill beyond stock" do
    assert_raises(Invoicing::Post::Error) { bill(@cust, [{ product: @batten, quantity: 101 }]) }
    assert_equal 0, Invoice.count
  end

  test "e-way bill flagged over threshold" do
    inv = bill(@cust, [{ product: @batten, quantity: 100, rate_paise: 60000 }])
    assert inv.eway_required
  end

  test "cancel reverses stock and ledger, never deletes" do
    inv = bill
    Invoicing::Cancel.call(inv, reason: "Wrong customer")
    assert inv.reload.cancelled?
    assert_equal 500, @bulb.stock
    assert_equal 0, @cust.balance_paise
    assert_equal 2, inv.ledger_entries.count
  end

  test "shortfall credit note restocks and reduces what is owed" do
    inv = bill(@cust, [{ product: @bulb, quantity: 10 }])
    line = inv.lines.first
    cn = Invoicing::CreditNote.call(invoice: inv, reason: "shortfall", restock_bucket: "sellable", items: [{ invoice_line: line, quantity: 2 }])
    assert_equal 492, @bulb.stock
    assert_equal inv.total_paise - cn.total_paise, @cust.balance_paise
    assert_equal inv.total_paise - cn.total_paise, inv.reload.outstanding_paise
    assert_raises(Invoicing::CreditNote::Error) { Invoicing::CreditNote.call(invoice: inv, reason: "return", items: [{ invoice_line: line, quantity: 9 }]) }
  end
end
