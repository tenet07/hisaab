class CreditNote < ApplicationRecord
  REASONS = { "shortfall" => "Short delivered", "return" => "Goods returned", "rate_difference" => "Rate difference",
              "defective" => "Defective, not replaced" }.freeze

  belongs_to :customer
  belongs_to :invoice
  belongs_to :created_by, class_name: "User", optional: true
  has_many :lines, class_name: "CreditNoteLine", dependent: :restrict_with_error, inverse_of: :credit_note
  has_many :whatsapp_messages, as: :document
  money :taxable, :cgst, :sgst, :igst, :total
  validates :reason, inclusion: { in: REASONS.keys }
  scope :recent, -> { order(note_date: :desc, id: :desc) }
  def tax_paise = cgst_paise + sgst_paise + igst_paise
  def reason_label = REASONS[reason]
end
