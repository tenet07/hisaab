class InvoiceLine < ApplicationRecord
  belongs_to :invoice
  belongs_to :product
  def total_paise = taxable_paise + tax_paise
  def to_core
    Shop::Line.new(sku: product.sku, name: product.name, hsn: product.hsn, qty: qty,
                   unit_price_paise: unit_price_paise, gst_bp: gst_bp,
                   discount_paise: discount_paise, price_includes_tax: price_includes_tax)
  end
end
