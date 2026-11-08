class Product < ApplicationRecord
  has_many :stock_movements, dependent: :restrict_with_error
  has_many :invoice_lines, dependent: :restrict_with_error
  validates :sku, presence: true, uniqueness: true
  validates :name, :brand, :hsn, presence: true
  validates :gst_bp, inclusion: { in: [0, 500, 1200, 1800, 2800] }
  validates :retail_price_paise, :wholesale_price_paise, numericality: { greater_than: 0 }

  def stock(bucket = :sellable) = stock_movements.where(bucket: bucket.to_s).sum(:qty)
  def snapshot = Shop::BUCKETS.to_h { |b| [b, stock(b)] }
  # billed but not yet handed over: still physically in the shop
  def awaiting_delivery
    DeliveryItem.joins(:delivery, :invoice_line)
                .where(deliveries: { status: Delivery::OPEN }, invoice_lines: { product_id: id })
                .sum("invoice_lines.qty")
  end
  def expected_on_shelf = stock + awaiting_delivery

  def low_stock? = reorder_level.positive? && stock <= reorder_level
  has_many :purchase_lines, dependent: :restrict_with_error
  # Latest purchase cost per piece including GST (0 if never bought through a bill).
  def last_cost_paise
    l = purchase_lines.joins(:purchase_bill).order("purchase_bills.date DESC, purchase_lines.id DESC").first
    l ? Shop::Money.div_round(l.total_paise, l.qty) : 0
  end
  def price_for(customer) = customer.price_tier == "retail" ? retail_price_paise : wholesale_price_paise
  def label = "#{brand} #{name} (#{sku})"
end
