class Payment < ApplicationRecord
  MODES = { "cash" => "Cash", "upi" => "UPI", "cheque" => "Cheque", "bank" => "Bank transfer" }.freeze

  belongs_to :customer
  belongs_to :collected_by, class_name: "User", optional: true
  has_many :allocations, class_name: "PaymentAllocation", dependent: :restrict_with_error
  has_many :ledger_entries, as: :document
  has_many :whatsapp_messages, as: :document
  money :amount

  validates :mode, inclusion: { in: MODES.keys }
  validates :amount_paise, numericality: { greater_than: 0 }
  validates :reference, presence: { message: "is needed for a cheque or UPI (cheque no. / UTR)" }, if: -> { %w[cheque].include?(mode) }
  scope :cleared, -> { where(status: "cleared") }
  scope :recent, -> { order(received_on: :desc, id: :desc) }

  def bounced? = status == "bounced"
  def mode_label = MODES[mode]
  def allocated_paise = allocations.sum(:amount_paise)
  def unallocated_paise = bounced? ? 0 : amount_paise - allocated_paise
end
