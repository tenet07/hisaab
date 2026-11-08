require "test_helper"

class ScreensTest < ActionDispatch::IntegrationTest
  setup { setup_shop }

  def login(user)
    post session_path, params: { user_id: user.id, pin: "1234" }
  end

  test "login required and wrong PIN rejected" do
    get root_path
    assert_redirected_to new_session_path
    post session_path, params: { user_id: @acct.id, pin: "0000" }
    assert_redirected_to new_session_path
  end

  test "accounts can bill, view, and export to Tally" do
    login(@acct)
    get root_path
    assert_response :success
    post invoices_path, params: { customer_id: @shop.id, items: { "0" => { product_id: @bulb.id, qty: "5", discount: "" } } }
    inv = Invoice.last
    assert_redirected_to invoice_path(inv)
    get invoice_path(inv)
    assert_response :success
    assert_includes response.body, "wa.me/919811000001"
    get tally_export_path, params: { from: Date.current, to: Date.current }
    assert_response :success
    assert_includes response.body, inv.number
    %w[/customers /products /invoices/new /claims /replacements/new /markets /tally].each do |p|
      get p
      assert_response :success, p
    end
    get customer_path(@shop)
    assert_response :success
    get statement_customer_path(@shop)
    assert_response :success
    get product_path(@bulb)
    assert_response :success
  end

  test "salesman visit screen, payment and blocked office pages" do
    Books.opening_balance(@shop, 25_000, user: @acct)
    login(@sales)
    assert_redirected_to customers_path
    get visit_customer_path(@shop)
    assert_response :success
    assert_includes response.body, "₹250.00"
    post customer_payments_path(@shop), params: { amount: "100", mode: "cash" }
    assert_redirected_to visit_customer_path(@shop)
    assert_equal 15_000, @shop.balance_paise
    get claims_path
    assert_redirected_to root_path
    get tally_path
    assert_redirected_to root_path
  end

  test "friendly error when overselling" do
    login(@acct)
    post invoices_path, params: { customer_id: @shop.id, items: { "0" => { product_id: @bulb.id, qty: "999" } } }
    follow_redirect!
    assert_includes response.body, "Not enough"
  end
end
