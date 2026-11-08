# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../lib/shop"


def bulb(qty, price: "100", gst: 1800, incl: false, disc: 0)
  Shop::Line.new(sku: "PH-9W", name: "Philips 9W LED", hsn: "8539", qty: qty,
           unit_price_paise: Shop::Money.paise(price), gst_bp: gst,
           discount_paise: disc, price_includes_tax: incl)
end

def batten(qty)
  Shop::Line.new(sku: "SY-20W", name: "Syska 20W Batten", hsn: "9405", qty: qty,
           unit_price_paise: Shop::Money.paise("249.50"), gst_bp: 1800)
end

class MoneyTest < Minitest::Test
  def test_paise_and_format
    assert_equal 24_950, Shop::Money.paise("249.50")
    assert_equal "₹12,34,567.05", Shop::Money.format(123_456_705)
    assert_raises(ArgumentError) { Shop::Money.paise(249.5) }
  end
end

class GSTTest < Minitest::Test
  def test_intra_state_splits_cgst_sgst
    t = Shop::GST.tax_line(bulb(10), intra_state: true)
    assert_equal 100_000, t.taxable
    assert_equal 9_000, t.cgst
    assert_equal 9_000, t.sgst
    assert_equal 0, t.igst
  end

  def test_inter_state_uses_igst
    t = Shop::GST.tax_line(bulb(10), intra_state: false)
    assert_equal 18_000, t.igst
    assert_equal 0, t.cgst + t.sgst
  end

  def test_mrp_inclusive_total_equals_printed_price
    t = Shop::GST.tax_line(bulb(3, price: "99", incl: true), intra_state: true)
    assert_equal 29_700, t.total, "customer pays exactly 3 x ₹99"
    assert_equal 25_169, t.taxable
  end

  def test_odd_tax_paisa_goes_to_sgst
    t = Shop::GST.tax_line(bulb(1, price: "0.05"), intra_state: true) # tax 0.9 paise -> 1
    assert_equal t.tax, t.cgst + t.sgst
  end

  def test_discount_cannot_exceed_value
    assert_raises(ArgumentError) { Shop::GST.tax_line(bulb(1, disc: 20_000), intra_state: true) }
  end
end

class InvoiceTest < Minitest::Test
  def inv(lines = [bulb(10), batten(3)])
    Shop::Invoice.new(number: "INV/26-27/0001", date: Date.new(2026, 11, 7),
                customer_id: 1, lines: lines)
  end

  def test_totals_and_round_off
    i = inv
    assert_equal 100_000 + 74_850, i.taxable
    assert_equal 31_473, i.tax                   # 18000 + 13473
    assert_equal 206_323, i.exact_total
    assert_equal 206_300, i.total                # ₹2,063
    assert_equal(-23, i.round_off)
  end

  def test_hsn_summary_groups_by_hsn_and_rate
    s = inv.hsn_summary
    assert_equal %w[8539 9405], s.map { _1[:hsn] }.sort
    assert_equal inv.taxable, s.sum { _1[:taxable] }
  end

  def test_eway_bill_flag
    refute inv.needs_eway_bill?
    assert inv([bulb(600)]).needs_eway_bill? # ₹70,800
  end
end

class StockLedgerTest < Minitest::Test
  def setup
    @s = Shop::StockLedger.new
    @s.opening("PH-9W", 100, by: "accounts")
  end

  def test_sale_reduces_sellable
    @s.sale(Shop::Invoice.new(number: "I1", date: Date.today, customer_id: 1, lines: [bulb(30)]), by: "counter")
    assert_equal 70, @s.balance("PH-9W")
  end

  def test_cannot_sell_more_than_stock_and_nothing_is_posted
    before = @s.movements.size
    assert_raises(Shop::InsufficientStock) do
      @s.sale(Shop::Invoice.new(number: "I2", date: Date.today, customer_id: 1, lines: [bulb(101)]), by: "counter")
    end
    assert_equal before, @s.movements.size
  end

  def test_replacement_keeps_defective_piece_tracked
    @s.replacement("PH-9W", qty: 2, ref: "R1", by: "salesman")
    assert_equal({ sellable: 98, awaiting_claim: 2, with_brand: 0, written_off: 0 }, @s.snapshot("PH-9W"))
  end

  def test_full_claim_lifecycle
    @s.replacement("PH-9W", qty: 5, ref: "R1", by: "counter")
    @s.send_claim("PH-9W", 5, ref: "CLM-1", by: "accounts")
    @s.settle_claim("PH-9W", 3, mode: :new_piece, ref: "CLM-1", by: "accounts")
    @s.reject_claim("PH-9W", 2, ref: "CLM-1", by: "accounts", approved_by: "owner")
    assert_equal({ sellable: 98, awaiting_claim: 0, with_brand: 0, written_off: 2 }, @s.snapshot("PH-9W"))
  end

  def test_cannot_claim_pieces_not_awaiting
    assert_raises(Shop::InsufficientStock) { @s.send_claim("PH-9W", 1, ref: "C", by: "accounts") }
  end

  def test_write_off_needs_owner
    @s.replacement("PH-9W", ref: "R", by: "counter")
    @s.send_claim("PH-9W", 1, ref: "C", by: "accounts")
    assert_raises(Shop::InvalidMove) { @s.reject_claim("PH-9W", 1, ref: "C", by: "accounts", approved_by: nil) }
  end

  def test_count_adjustment_posts_difference_with_reason
    m = @s.count_adjustment("PH-9W", counted: 96, reason: "breakage", by: "owner")
    assert_equal(-4, m.first.qty)
    assert_equal 96, @s.balance("PH-9W")
    assert_raises(Shop::InvalidMove) { @s.count_adjustment("PH-9W", counted: 90, reason: " ", by: "owner") }
  end

  def test_every_movement_needs_a_user
    assert_raises(Shop::InvalidMove) { @s.purchase("PH-9W", 10, ref: "P1", by: nil) }
  end
end

class CustomerLedgerTest < Minitest::Test
  def setup
    @c = Shop::CustomerLedger.new
    @c.opening_balance(7, 50_000_00, date: Date.new(2026, 8, 1), by: "accounts")
    @c.invoice(Shop::Invoice.new(number: "I1", date: Date.new(2026, 10, 1), customer_id: 7, lines: [bulb(100)]), by: "counter")
  end

  def test_balance
    assert_equal 50_000_00 + 11_800_00, @c.balance(7)
  end

  def test_payment_settles_oldest_first
    @c.payment(7, 55_000_00, date: Date.new(2026, 11, 1), mode: :upi, ref: "UPI123", by: "salesman")
    open = @c.open_items(7)
    assert_equal ["I1"], open.map { _1[:ref] }
    assert_equal 6_800_00, open.first[:due]
  end

  def test_ageing
    a = @c.ageing(7, as_of: Date.new(2026, 11, 7))
    assert_equal 50_000_00, a["90+"]
    assert_equal 11_800_00, a["31-60"]
  end

  def test_bad_payment_mode_rejected
    assert_raises(ArgumentError) { @c.payment(7, 100, date: Date.today, mode: :barter, ref: "x", by: "s") }
  end
end

class WarrantyTest < Minitest::Test
  def test_warranty_window
    sold = Date.new(2025, 12, 15)
    assert Shop::Warranty.valid?(sold_on: sold, warranty_months: 12, today: Date.new(2026, 12, 15))
    refute Shop::Warranty.valid?(sold_on: sold, warranty_months: 12, today: Date.new(2026, 12, 16))
    refute Shop::Warranty.valid?(sold_on: sold, warranty_months: 0, today: sold)
  end
end

class TallyExportTest < Minitest::Test
  def test_vouchers_balance_and_xml_is_escaped
    inv = Shop::Invoice.new(number: "INV/1", date: Date.new(2026, 11, 7), customer_id: 1,
                      lines: [bulb(10), batten(3)])
    t = Shop::TallyExport.new(company: "Solanki Electricals")
    entries = t.sales_entries(inv, "Gupta & Sons")
    assert_equal 0, entries.sum { _2 }, "Tally rejects unbalanced vouchers"

    xml = t.to_xml(invoices: [[inv, "Gupta & Sons"]],
                   receipts: [{ date: Date.new(2026, 11, 8), ref: "RC/1",
                                party: "Gupta & Sons", amount: 1_000_00, mode: :cash }])
    assert_includes xml, "Gupta &amp; Sons"
    assert_includes xml, "<AMOUNT>-2063.00</AMOUNT>"
    assert_includes xml, "<DATE>20261107</DATE>"
    assert_equal 2, xml.scan("<VOUCHER ").size
  end
end

class TallyCreditNoteTest < Minitest::Test
  def test_credit_note_balances
    t = Shop::TallyExport.new(company: "X")
    cn = { date: Date.new(2026, 11, 7), number: "CN/26-27/0001", party: "Gupta", taxable: 6_200, cgst: 558, sgst: 558, igst: 0, total: 7_316 }
    assert_equal 0, t.credit_note_entries(cn).sum { _2 }
    xml = t.to_xml(credit_notes: [cn])
    assert_includes xml, 'VCHTYPE="Credit Note"'
    assert_raises(ArgumentError) { t.credit_note_entries(cn.merge(total: 1)) }
  end
end

class TallyPurchaseTest < Minitest::Test
  def test_purchase_payment_and_claim_vouchers_balance
    t = Shop::TallyExport.new(company: "X")
    bill = Shop::Invoice.new(number: "PH/889", date: Date.new(2026, 11, 7), customer_id: 1,
                             lines: [Shop::Line.new(sku: "B", name: "Bulb", hsn: "8539", qty: 333, unit_price_paise: 6_150, gst_bp: 1800)])
    assert_equal 0, t.purchase_entries(bill, "Philips Distributor").sum { _2 }
    refute bill.round_off.zero?, "exercise the round-off path"
    assert_equal 0, t.payment_entries({ party: "P", amount: 5_000_00, mode: :upi }).sum { _2 }
    assert_equal 0, t.claim_credit_entries({ party: "P", amount: 1_200_00 }).sum { _2 }
    xml = t.to_xml(purchases: [[bill, "Philips Distributor"]], payments: [{ date: bill.date, ref: "UTR1", party: "P", amount: 100, mode: :upi }],
                   claim_credits: [{ date: bill.date, number: "CN-9", party: "P", amount: 100 }])
    %w[Purchase Payment Journal].each { |v| assert_includes xml, %(VCHTYPE="#{v}") }
  end
end

class MoneyWordsTest < Minitest::Test
  def test_indian_words
    assert_equal "Rupees Two Thousand Sixty-Three Only", Shop::Money.words(206_300)
    assert_equal "Rupees One Lakh Twelve Thousand Five Hundred Eighty-Eight and Fifty Paise Only", Shop::Money.words(11_258_850)
    assert_equal "Rupees Twelve Crore Thirty-Four Lakh Fifty-Six Thousand Seven Hundred Eighty-Nine Only", Shop::Money.words(12_345_678_900)
    assert_equal "Rupees Zero Only", Shop::Money.words(0)
    assert_equal "Rupees One Hundred Only", Shop::Money.words(10_000)
    assert_equal "Rupees One Thousand Crore Only", Shop::Money.words(1_000_000_000_000)
  end

  def test_state_codes
    assert_equal "Haryana", Shop::STATES["06"]
    assert_equal "Madhya Pradesh", Shop::STATES["23"]
  end
end
