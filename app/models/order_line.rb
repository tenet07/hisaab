class OrderLine < ApplicationRecord
  belongs_to :order, inverse_of: :lines
  belongs_to :product, optional: true
  validates :quantity, numericality: { greater_than: 0, only_integer: true }
  validates :discount_pct, numericality: { in: 0..100 }

  def effective_rate_paise = rate_paise || product&.price_paise_for(order.customer).to_i
end
