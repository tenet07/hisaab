# Monthly rotating physical count: a slice of products each month so the whole range is
# counted in a cycle. Differences post as count_adjustment movements, with a reason.
class StockCount < ApplicationRecord
  CYCLE_MONTHS = 3
  belongs_to :counted_by, class_name: "User", optional: true
  has_many :lines, class_name: "StockCountLine", dependent: :destroy
  has_many :stock_movements, as: :document
  has_many :approvals, as: :subject
  def posted? = status == "posted"
  def variance_lines = lines.select { _1.counted_qty && _1.counted_qty != _1.system_qty }

  # This month's slice: products whose id falls in the month's position of the cycle
  def self.products_due(date = Date.current)
    slot = (date.year * 12 + date.month) % CYCLE_MONTHS
    Product.active.where("products.id % ? = ?", CYCLE_MONTHS, slot).order(:brand_id, :name)
  end
end
