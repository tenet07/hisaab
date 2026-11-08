class SupplierPayment < ApplicationRecord
  belongs_to :supplier
  belongs_to :user
  validates :mode, inclusion: { in: Payment::MODES }
end
