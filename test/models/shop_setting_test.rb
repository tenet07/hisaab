require "test_helper"

class ShopSettingTest < ActiveSupport::TestCase
  test "one row, created on first use, with safe defaults" do
    s = ShopSetting.current
    assert_equal 1, ShopSetting.count
    assert_equal "06", s.state_code
    assert_same s, ShopSetting.current, "cached for the request"
  end

  test "GSTIN sets the state; prefixes are short, distinct and uppercased" do
    s = ShopSetting.current
    s.update!(gstin: "23aabcs1234a1z5", invoice_prefix: "se", credit_note_prefix: "cn")
    assert_equal "23", s.state_code
    assert_equal "Madhya Pradesh", s.state_name
    assert_equal "SE", s.invoice_prefix
    refute s.reload.update(invoice_prefix: "TOOLONG")
    refute s.reload.update(invoice_prefix: "CN", credit_note_prefix: "CN")
    refute s.reload.update(upi_id: "not a upi")
    assert s.reload.update(upi_id: "solanki.elec@okhdfcbank", bank_ifsc: "hdfc0001234")
    assert_equal "HDFC0001234", s.bank_ifsc
  end

  test "bill numbers use the shop's prefix and stay within GST's 16 characters" do
    ShopSetting.current.update!(invoice_prefix: "SOLE")
    n = Invoice.next_number(Date.new(2027, 3, 31))
    assert_equal "SOLE/26-27/00001", n
    assert_operator n.length, :<=, 16
    assert_equal "SOLE/27-28/00001", Invoice.next_number(Date.new(2027, 4, 1)), "new financial year restarts"
  end

  test "changing the shop's state changes who is billed IGST" do
    m = Market.create!(name: "M")
    delhi = Customer.create!(name: "D", gstin: "07AADCD9999C1Z9", market: m)
    local = Customer.create!(name: "L", market: m)
    assert_equal "06", local.state_code, "unregistered customers default to the shop's state"
    refute delhi.intra_state?
    ShopSetting.current.update!(gstin: "07AAACS1234D1Z1")
    assert delhi.reload.intra_state?
  end

  test "tally ledger names override defaults" do
    s = ShopSetting.current
    s.update!(tally_ledgers: { "sales" => "Sales @18%", "cgst" => "" })
    assert_equal "Sales @18%", s.ledgers[:sales]
    assert_equal "Output CGST", s.ledgers[:cgst], "blank keeps the default"
  end
end
