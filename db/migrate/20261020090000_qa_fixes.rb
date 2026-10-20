# Payments can now be matched to an opening balance as well as to invoices; OTP attempts are counted.
class QaFixes < ActiveRecord::Migration[8.0]
  def change
    change_column_null :payment_allocations, :invoice_id, true
    add_reference :payment_allocations, :ledger_entry, foreign_key: true
    add_check_constraint :payment_allocations, "(invoice_id IS NULL) <> (ledger_entry_id IS NULL)", name: "allocation_one_target"
    add_column :deliveries, :otp_failures, :integer, null: false, default: 0
    change_column_default :shop_settings, :writeoff_approval_paise, from: 0, to: 500_000
    add_column :credit_notes, :round_off_paise, :bigint, null: false, default: 0
  end
end
