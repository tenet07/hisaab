require "test_helper"

class DeliveryScreensTest < ActionDispatch::IntegrationTest
  setup { setup_shop; setup_delivery }
  def login(u) = post(session_path, params: { user_id: u.id, pin: "1234" })

  test "driver runs a stop end to end and sees nothing else" do
    login(@driver)
    assert_redirected_to run_deliveries_path
    get run_deliveries_path
    assert_includes response.body, "Gupta"
    refute_includes response.body, @del.otp, "the code must never be shown to the driver"
    get delivery_path(@del)
    refute_includes response.body, @del.otp
    post load_delivery_path(@del), params: { loaded: { @item.id => "10" } }
    post complete_delivery_path(@del), params: { delivered: { @item.id => "10" }, otp: @del.otp, cash: "100", cash_mode: "cash" }
    assert_redirected_to run_deliveries_path
    assert_equal "delivered", @del.reload.status
    %w[/customers /products / /invoices /claims].each do |p|
      get p
      assert_redirected_to run_deliveries_path, p
    end
  end

  test "another driver can't open this stop" do
    other = User.create!(name: "D2", role: "delivery", password: "1234")
    login(other)
    get delivery_path(@del)
    assert_redirected_to run_deliveries_path
  end

  test "office plans, sees summary and tally includes credit notes" do
    Books.load_delivery(@del, loaded: {}, user: @driver)
    Books.complete_delivery(@del, delivered: { @item.id.to_s => "9" }, reasons: { @item.id.to_s => "broken" }, otp: @del.otp, user: @driver)
    login(@acct)
    get deliveries_path
    assert_response :success
    get summary_deliveries_path
    assert_response :success
    assert_includes response.body, "broken"
    get invoice_path(@inv)
    assert_includes response.body, "Credit note"
    get tally_export_path, params: { from: Date.current, to: Date.current }
    assert_includes response.body, 'VCHTYPE="Credit Note"'
    get new_invoice_path
    assert_response :success
  end
end
