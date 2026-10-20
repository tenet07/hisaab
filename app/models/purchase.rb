class Purchase < ApplicationRecord
  belongs_to :supplier
  belongs_to :created_by, class_name: "User", optional: true
  has_many :lines, class_name: "PurchaseLine", dependent: :restrict_with_error, inverse_of: :purchase
  has_many :stock_movements, as: :document
  money :taxable, :tax, :total
  validates :bill_no, presence: true, uniqueness: { scope: :supplier_id, message: "already entered for this supplier" }
  validates :bill_date, presence: true
  scope :recent, -> { order(bill_date: :desc, id: :desc) }
end
