require "test_helper"

class GstTest < ActiveSupport::TestCase
  test "GSTIN checksum" do
    g = Gstin.with_checksum("27AAPFU0939F1Z")
    assert Gstin.valid?(g)
    refute Gstin.valid?(g[0, 14] + (g[14] == "A" ? "B" : "A"))
  end

  test "Indian money formatting and words" do
    assert_equal "₹12,34,567.89", Money.format(123456789)
    assert_equal "One Lakh Rupees Only", Money.in_words(10_000_000)
    assert_equal "2026-27", FinancialYear.for(Date.new(2027, 3, 31))
  end

  test "GSTR-1 splits B2B and B2C and Tally XML builds" do
    build_shop
    bill
    walk = Customer.create!(shop_name: "Cash", phone: "9100000000", price_tier: "retail")
    bill(walk, [{ product: @bulb, quantity: 1 }], inclusive: true)
    r = Reports::Gstr1.new(Date.current)
    assert_equal 1, r.b2b.size
    assert_equal 1, r.b2cs_invoices.size
    assert_includes r.csv("hsn"), "85395000"
    assert_includes Reports::Tally.new(Date.current.beginning_of_month, Date.current).to_xml, "<VOUCHERTYPENAME>Sales</VOUCHERTYPENAME>"
  end
end
