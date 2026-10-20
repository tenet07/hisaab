class Product < ApplicationRecord
  include Audited

  belongs_to :brand
  has_many :stock_movements, dependent: :restrict_with_error
  has_many :invoice_lines, dependent: :restrict_with_error

  money :mrp, :retail, :wholesale, :purchase
  validates :sku, presence: true, uniqueness: { case_sensitive: false }
  validates :name, :hsn, presence: true
  validates :hsn, format: { with: /\A\d{4,8}\z/, message: "must be 4–8 digits" }
  validates :gst_rate, inclusion: { in: [0, 0.25, 3, 5, 12, 18, 28].map(&:to_d), message: "isn't a GST slab" }
  normalizes :sku, with: ->(s) { s.strip.upcase }

  scope :active, -> { where(active: true) }
  scope :search, ->(q) {
    next all if q.blank?
    t = "%#{sanitize_sql_like(q.strip)}%"
    joins(:brand).where("products.name ILIKE :t OR products.sku ILIKE :t OR products.model ILIKE :t OR " \
                        "products.aliases ILIKE :t OR brands.name ILIKE :t", t: t)
  }

  def display_name = [brand&.name, name].compact.join(" ")
  def label = "#{display_name} (#{sku})"
  def effective_warranty_months = warranty_months || brand.warranty_months

  # ── stock (always derived from the ledger) ──
  def stock(bucket = "sellable") = stock_movements.where(bucket: bucket).sum(:quantity)
  def stock_by_bucket = StockMovement::BUCKETS.index_with { 0 }.merge(stock_movements.group(:bucket).sum(:quantity))

  def self.with_stock(bucket = "sellable")
    select("products.*, COALESCE((SELECT SUM(quantity) FROM stock_movements sm WHERE sm.product_id = products.id " \
           "AND sm.bucket = #{connection.quote(bucket)}), 0) AS stock_qty")
  end

  # Products at or below reorder level, with their sellable stock
  def self.below_reorder
    active.with_stock.where("reorder_level > 0").to_a.select { |p| p.stock_qty.to_i <= p.reorder_level }
  end

  def price_paise_for(customer)
    case customer&.price_tier
    when "retail" then retail_paise.positive? ? retail_paise : mrp_paise
    when "mrp" then mrp_paise
    else wholesale_paise.positive? ? wholesale_paise : retail_paise
    end
  end

  def margin_paise(rate_paise = wholesale_paise) = rate_paise - purchase_paise
  def alias_list = aliases.to_s.split(/[,\n]/).map(&:strip).reject(&:blank?)
end
