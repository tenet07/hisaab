class Payment < ApplicationRecord
  MODES = %w[cash upi cheque].freeze
  belongs_to :customer
  belongs_to :user
  belongs_to :delivery, optional: true
  validates :mode, inclusion: { in: MODES }
  validates :amount_paise, numericality: { greater_than: 0 }
end
