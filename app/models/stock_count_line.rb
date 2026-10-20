class StockCountLine < ApplicationRecord
  belongs_to :stock_count
  belongs_to :product
  def variance = counted_qty.nil? ? 0 : counted_qty - system_qty
end
