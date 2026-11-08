require "test_helper"

class SupplierScreensTest < ActionDispatch::IntegrationTest
  setup do
    setup_shop
    @phil = Supplier.create!(name: "Signify Dist", brands: "Philips")
    post session_path, params: { user_id: @acct.id, pin: "1234" }
  end

  test "enter a purchase, pay, and export to Tally" do
    get new_purchase_bill_path(supplier_id: @phil.id)
    assert_response :success
    post purchase_bills_path, params: { supplier_id: @phil.id, number: "SDG/1", date: Date.current.to_s, printed_total: "713.90",
                                        items: { "0" => { product_id: @bulb.id, qty: "10", rate: "60.50", discount: "" } } }
    bill = PurchaseBill.last
    assert_redirected_to purchase_bill_path(bill)
    assert_equal 110, @bulb.stock
    post supplier_supplier_payments_path(@phil), params: { amount: "500", mode: "upi", ref: "UTR1", date: Date.current.to_s }
    assert_redirected_to supplier_path(@phil)
    assert_equal 71_400 - 50_000, @phil.payable_paise # ₹713.90 rounds to ₹714
    %W[/suppliers /suppliers/#{@phil.id} /purchases /purchases/#{bill.id} / /products/#{@bulb.id} /suppliers/new].each do |p|
      get p
      assert_response :success, p
    end
    get tally_export_path, params: { from: Date.current, to: Date.current }
    assert_includes response.body, 'VCHTYPE="Purchase"'
    assert_includes response.body, 'VCHTYPE="Payment"'
  end

  test "salesman can't see suppliers" do
    delete session_path
    post session_path, params: { user_id: @sales.id, pin: "1234" }
    get suppliers_path
    assert_redirected_to root_path
  end
end
