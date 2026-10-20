require "test_helper"

class PaymentsTest < ActiveSupport::TestCase
  setup { build_shop }

  test "payments clear the oldest bills first, partial allowed" do
    a = bill(@cust, [{ product: @bulb, quantity: 10 }], date: Date.current - 20)
    b = bill(@cust, [{ product: @bulb, quantity: 10 }], date: Date.current - 5)
    Payments::Record.call(customer: @cust, amount_paise: a.total_paise + 1000, mode: "cash")
    assert_equal 0, a.reload.outstanding_paise
    assert_equal b.total_paise - 1000, b.reload.outstanding_paise
    assert_equal b.total_paise - 1000, @cust.balance_paise
  end

  test "an advance is applied to the next bill" do
    Payments::Record.call(customer: @cust, amount_paise: 50000, mode: "upi", reference: "UTR1")
    inv = bill
    assert_equal [inv.total_paise - 50000, 0].max, inv.reload.outstanding_paise
  end

  test "client_uuid makes offline replays idempotent" do
    2.times { Payments::Record.call(customer: @cust, amount_paise: 1000, mode: "cash", client_uuid: "abc") }
    assert_equal 1, Payment.count
  end

  test "a bounced cheque debits back and frees the matches" do
    inv = bill
    pay = Payments::Record.call(customer: @cust, amount_paise: inv.total_paise, mode: "cheque", reference: "000123")
    Payments::Bounce.call(pay, reason: "Insufficient funds")
    assert_equal inv.total_paise, @cust.balance_paise
    assert_equal inv.total_paise, inv.reload.outstanding_paise
  end
end
