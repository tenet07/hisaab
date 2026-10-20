require "test_helper"

class ClaimsTest < ActiveSupport::TestCase
  setup { build_shop }

  test "a swap is two movements and warranty comes from the invoice" do
    bill(@cust, [{ product: @bulb, quantity: 10 }], date: Date.current - 30)
    r = Replacements::Intake.call(customer: @cust, product: @bulb, outcome: "swapped", defect: "Not glowing")
    assert r.warranty_valid
    assert_equal 489, @bulb.stock("sellable")
    assert_equal 1, @bulb.stock("awaiting_claim")
    assert_equal 2, r.stock_movements.count
  end

  test "out-of-warranty pieces cannot be swapped" do
    bill(@cust, [{ product: @bulb, quantity: 1 }], date: Date.current - 400)
    assert_raises(Replacements::Intake::Error) { Replacements::Intake.call(customer: @cust, product: @bulb, outcome: "swapped") }
  end

  test "claim batch: sent, partly credited, partly replaced, rejected goes for write-off approval" do
    bill(@cust, [{ product: @bulb, quantity: 10 }], date: Date.current - 30)
    reps = 3.times.map { Replacements::Intake.call(customer: @cust, product: @bulb, outcome: "swapped") }
    claim = Claims::Batch.build(@brand, reps)
    Claims::Batch.dispatch!(claim, challan_no: "DC1")
    assert_equal 3, @bulb.stock("with_brand")
    Claims::Batch.settle!(claim, outcomes: { reps[0].id => { result: "credited", amount_paise: 5000 } }, credit_note_ref: "PCN-1")
    refute claim.reload.settled?
    assert_equal 5000, claim.credited_paise
    assert_equal(-5000, @supplier.ledger_entries.where(entry_type: "credit_note").sum("credit_paise - debit_paise"))
    Claims::Batch.settle!(claim, outcomes: { reps[1].id => { result: "replaced" }, reps[2].id => { result: "rejected" } })
    assert claim.reload.settled?
    assert_equal 0, @bulb.stock("with_brand")
    assert_equal 1, @bulb.stock("awaiting_claim")
    approval = Approval.pending.find_by(kind: "write_off")
    Approvals.decide!(approval, approve: true)
    assert_equal 1, @bulb.stock("written_off")
    assert_equal 0, @bulb.stock("awaiting_claim")
  end

  test "claims with no response are flagged after N days" do
    bill(@cust, [{ product: @bulb, quantity: 10 }], date: Date.current - 30)
    r = Replacements::Intake.call(customer: @cust, product: @bulb, outcome: "swapped")
    claim = Claims::Batch.build(@brand, [r])
    Claims::Batch.dispatch!(claim, challan_no: "DC2", sent_on: Date.current - 60)
    assert claim.flagged?
  end
end
