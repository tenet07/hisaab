# One gap-free serial per document kind per financial year (GST rule 46 wants invoice serials unique per FY).
class DocumentSequence < ApplicationRecord
  PREFIXES = {
    "invoice" => -> { ShopSetting.current.invoice_prefix }, "credit_note" => -> { "CN" }, "payment" => -> { "RCPT" },
    "order" => -> { "ORD" }, "replacement" => -> { "RPL" }, "brand_claim" => -> { "CLM" }
  }.freeze

  # Locks the row, so two counters billing at the same moment never get the same number.
  # Must run inside the caller's transaction: a rolled-back bill gives its number back.
  def self.next!(kind, date = Date.current)
    fy = FinancialYear.for(date)
    seq = lock.find_by(kind: kind, fy: fy) || begin
      create!(kind: kind, fy: fy)
    rescue ActiveRecord::RecordNotUnique
      lock.find_by!(kind: kind, fy: fy)
    end
    seq.increment!(:last_number)
    prefix = PREFIXES.fetch(kind).call
    ["#{prefix}/#{fy}/#{seq.last_number.to_s.rjust(5, '0')}", fy]
  end
end
