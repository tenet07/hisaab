class CreditNoteLine < ApplicationRecord
  belongs_to :credit_note, inverse_of: :lines
  belongs_to :product
  belongs_to :invoice_line, optional: true
  money :rate, :taxable, :tax, :total
end
