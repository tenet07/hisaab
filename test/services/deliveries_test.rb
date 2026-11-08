require "test_helper"

class DeliveriesTest < ActiveSupport::TestCase
  setup { setup_shop; setup_delivery }

  test "wholesale bill creates a delivery for the market's day and driver" do
    assert_equal "pending", @del.status
    assert_equal Date.current, @del.run_date
    assert_equal @driver, @del.assigned_to
    assert_match(/\A\d{4}\z/, @del.otp)
    assert_equal 10, @bulb.awaiting_delivery
    assert_equal 100, @bulb.expected_on_shelf
  end

  test "next delivery date rolls forward to the market's day" do
    @market.update!(delivery_day: Date::ABBR_DAYNAMES[(Date.current + 3).wday])
    assert_equal Date.current + 3, Books.next_delivery_date(@market, Date.current)
  end

  test "counter sale that the customer takes now has no delivery" do
    inv = Books.create_invoice(customer: @shop, user: @acct, items: [{ product: @bulb, qty: 1 }], deliver: false)
    assert_nil inv.delivery
  end

  test "full delivery with the customer's code" do
    Books.load_delivery(@del, loaded: {}, user: @driver)
    assert_raises(Books::Error) { Books.complete_delivery(@del, delivered: {}, otp: "0000x", user: @driver) }
    assert_raises(Books::Error) { Books.complete_delivery(@del, delivered: {}, user: @driver) }
    Books.complete_delivery(@del, delivered: {}, otp: @del.otp, cash_paise: 20_000, user: @driver)
    @del.reload
    assert_equal "delivered", @del.status
    assert_equal "otp", @del.proof_kind
    assert_equal 0, @bulb.awaiting_delivery
    assert_equal 73_200 - 20_000, @shop.balance_paise
    assert_equal @del, Payment.last.delivery
  end

  test "short delivery credits the customer and returns stock" do
    Books.load_delivery(@del, loaded: { @item.id.to_s => "8" }, user: @driver)
    assert_raises(Books::Error) { Books.complete_delivery(@del, delivered: { @item.id.to_s => "9" }, otp: @del.otp, user: @driver) }
    assert_raises(Books::Error) { Books.complete_delivery(@del, delivered: { @item.id.to_s => "7" }, otp: @del.otp, user: @driver) }
    Books.complete_delivery(@del, delivered: { @item.id.to_s => "7" }, reasons: { @item.id.to_s => "2 broken, 1 missing" },
                            damaged: { @item.id.to_s => "2" }, otp: @del.otp, user: @driver)
    cn = CreditNote.last
    assert_equal "partly_delivered", @del.reload.status
    assert_equal 18_600, cn.taxable_paise          # 3 x 62.00
    assert_equal 3_348, cn.cgst_paise + cn.sgst_paise   # 18% of 186.00
    assert_equal 21_948, cn.total_paise
    assert_equal 73_200 - 21_948, @shop.balance_paise
    assert_equal 91, @bulb.stock                    # 100 - 10 sold + 1 good piece back
    assert_equal 2, @bulb.stock(:written_off)       # 2 broken
    assert_match(/2 broken/, cn.reason)
  end

  test "photo proof works when there is no code" do
    Books.load_delivery(@del, loaded: {}, user: @driver)
    Books.complete_delivery(@del, delivered: {}, photo: { data: "jpegbytes", type: "image/jpeg" }, user: @driver)
    assert_equal "photo", @del.reload.proof_kind
  end

  test "failed delivery keeps the bill and can be rescheduled" do
    Books.load_delivery(@del, loaded: {}, user: @driver)
    assert_raises(Books::Error) { Books.fail_delivery(@del, reason: " ", user: @driver) }
    Books.fail_delivery(@del, reason: "Shop closed", user: @driver)
    assert_equal "failed", @del.reload.status
    assert_equal 73_200, @shop.balance_paise
    assert_raises(Books::Error) { Books.reschedule_delivery(@del, run_date: Date.current + 1, user: @driver) }
    Books.reschedule_delivery(@del, run_date: Date.current + 1, user: @acct)
    assert_equal "pending", @del.reload.status
    assert_nil @del.items.first.loaded_qty
  end

  test "delivered bills can't be cancelled; undelivered ones cancel the delivery" do
    Books.load_delivery(@del, loaded: {}, user: @driver)
    Books.complete_delivery(@del, delivered: {}, otp: @del.otp, user: @driver)
    assert_raises(Books::Error) { Books.cancel_invoice(@inv, user: @acct, reason: "x") }
    inv2 = Books.create_invoice(customer: @shop, user: @acct, items: [{ product: @bulb, qty: 1 }])
    Books.cancel_invoice(inv2, user: @acct, reason: "duplicate")
    assert_equal "cancelled", inv2.delivery.reload.status
  end

  test "only delivery staff can be assigned" do
    assert_raises(Books::Error) { Books.assign_delivery(@del, to: @sales, run_date: Date.current, user: @acct) }
    assert_raises(Books::Error) { Books.assign_delivery(@del, to: @driver, run_date: Date.current, user: @driver) }
  end
end
