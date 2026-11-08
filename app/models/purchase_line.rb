class PurchaseLine < ApplicationRecord
  belongs_to :purchase_bill
  belongs_to :product
  def total_paise = taxable_paise + tax_paise
  def to_core
    Shop::Line.new(sku: product.sku, name: product.name, hsn: product.hsn, qty: qty, unit_price_paise: rate_paise,
                   gst_bp: gst_bp, discount_paise: discount_paise, price_includes_tax: false)
  end
end
