class SupplierPayment < ApplicationRecord
  belongs_to :supplier
  belongs_to :created_by, class_name: "User", optional: true
  money :amount
  validates :amount_paise, numericality: { greater_than: 0 }
end
