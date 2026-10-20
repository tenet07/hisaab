class PaymentAllocation < ApplicationRecord
  belongs_to :payment
  belongs_to :invoice, optional: true
  belongs_to :ledger_entry, optional: true # an opening balance
  validates :amount_paise, numericality: { greater_than: 0 }

  def target_label = invoice&.number || "Opening balance"
end
