class DeliveryItem < ApplicationRecord
  belongs_to :delivery
  belongs_to :invoice_line
  delegate :product, :qty, to: :invoice_line
  attr_accessor :damaged_qty # set while posting a short delivery
  def short_qty = delivered_qty ? qty - delivered_qty : 0
end
