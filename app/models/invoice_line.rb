class InvoiceLine < ApplicationRecord
  belongs_to :invoice, inverse_of: :lines
  belongs_to :product
  money :rate, :taxable, :cgst, :sgst, :igst, :total
  def tax_paise = cgst_paise + sgst_paise + igst_paise
end
