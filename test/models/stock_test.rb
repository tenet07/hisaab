require "test_helper"

class StockTest < ActiveSupport::TestCase
  setup { build_shop }

  test "count adjustments post with reasons and need one for each difference" do
    sc = Stock::Count.open!(products: [@bulb, @batten])
    sc.lines.find_by(product: @bulb).update!(counted_qty: 497)
    assert_raises(Stock::Count::Error) { Stock::Count.post!(sc) }
    sc.lines.find_by(product: @bulb).update!(reason: "Breakage")
    Stock::Count.post!(sc)
    assert_equal 497, @bulb.stock
    assert_equal "Breakage", StockMovement.find_by(reason: "count_adjustment").note
  end

  test "reorder level comes from sales history" do
    bill(@cust, [{ product: @bulb, quantity: 90 }])
    row = Stock::Reorder.suggestions(window_days: 90, lead_days: 7, safety_days: 7).find { _1[:product] == @bulb }
    assert_equal 14, row[:suggested]
  end

  test "delivery drop with OTP, shortfall and cash" do
    inv = bill(@cust, [{ product: @bulb, quantity: 10 }])
    run = DispatchRun.create!(market: @market, run_date: Date.current, delivery_person: @owner)
    d = run.deliveries.create!(invoice: inv)
    assert_raises(Dispatch::Drop::Error) { Dispatch::Drop.complete!(d, otp: "0000x") }
    Dispatch::Drop.complete!(d.reload, otp: d.otp_code, shortfall: { inv.lines.first.id => 1 },
                                       payment: { amount_paise: 10000, mode: "cash" })
    assert_equal "partial", d.reload.status
    assert_equal 1, inv.credit_notes.count
    assert_equal 491, @bulb.stock
    assert_equal inv.total_paise - inv.credit_notes.sum(:total_paise) - 10000, @cust.balance_paise
  end
end
