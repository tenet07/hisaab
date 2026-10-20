class Supplier < ApplicationRecord
  include Audited
  belongs_to :brand, optional: true
  has_many :ledger_entries, as: :party
  has_many :purchases, dependent: :restrict_with_error
  has_many :supplier_payments, dependent: :restrict_with_error
  validates :name, presence: true

  # What the shop owes this supplier (credit = purchase, debit = payment)
  def payable_paise = ledger_entries.sum("credit_paise - debit_paise").to_i
end
