class PurchaseBill < ApplicationRecord
  belongs_to :supplier
  belongs_to :user
  has_many :lines, class_name: "PurchaseLine", dependent: :restrict_with_error
  def tax_paise = cgst_paise + sgst_paise + igst_paise
  def to_core
    Shop::Invoice.new(number: number, date: date, customer_id: supplier_id, intra_state: intra_state,
                      lines: lines.includes(:product).map(&:to_core))
  end
end
