require "test_helper"

class LedgerTest < ActiveSupport::TestCase
  setup { build_shop }

  test "the database refuses to update or delete ledger rows" do
    inv = bill
    entry = inv.ledger_entries.first
    assert_raises(ActiveRecord::ReadOnlyRecord) { entry.update!(debit_paise: 1) }
    assert_raises(ActiveRecord::StatementInvalid) { LedgerEntry.where(id: entry.id).update_all(debit_paise: 1) }
    assert_raises(ActiveRecord::StatementInvalid) { StockMovement.where(document: inv).delete_all }
  end

  test "an entry is one-sided and positive" do
    assert_raises(ActiveRecord::RecordInvalid) { LedgerEntry.create!(party: @cust, entry_date: Date.current, entry_type: "adjustment", debit_paise: 100, credit_paise: 100) }
    assert_raises(ActiveRecord::StatementInvalid) { LedgerEntry.insert!({ party_type: "Customer", party_id: @cust.id, entry_date: Date.current, entry_type: "x", debit_paise: 0, credit_paise: 0, created_at: Time.current }) }
  end

  test "stock and balance are sums of movements and entries" do
    assert_equal 500, @bulb.stock
    inv = bill
    assert_equal 490, @bulb.stock
    assert_equal inv.total_paise, @cust.balance_paise
    assert_equal "test", inv.ledger_entries.first.device
    assert_equal @owner, inv.ledger_entries.first.user
  end
end
