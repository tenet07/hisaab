class CreditNote < ApplicationRecord
  belongs_to :invoice
  belongs_to :customer
  belongs_to :delivery, optional: true
  belongs_to :user
  def tax_paise = cgst_paise + sgst_paise + igst_paise

  def self.next_number(date)
    fy = date.month >= 4 ? date.year : date.year - 1
    prefix = "#{ShopSetting.current.credit_note_prefix}/#{fy % 100}-#{(fy + 1) % 100}/"
    last = where("number LIKE ?", "#{prefix}%").maximum(:number)
    "#{prefix}#{((last ? last.split('/').last.to_i : 0) + 1).to_s.rjust(5, '0')}"
  end
end
