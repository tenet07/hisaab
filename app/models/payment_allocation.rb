class PaymentAllocation < ApplicationRecord
  belongs_to :payment
  belongs_to :invoice
  validates :amount_paise, numericality: { greater_than: 0 }
end
