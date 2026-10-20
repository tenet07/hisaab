class PurchaseLine < ApplicationRecord
  belongs_to :purchase, inverse_of: :lines
  belongs_to :product
  money :rate, :taxable, :tax
  validates :quantity, numericality: { greater_than: 0, only_integer: true }
end
