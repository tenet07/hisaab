# The customer (and supplier) ledger. A balance is debits minus credits; nothing else stores it.
class LedgerEntry < ApplicationRecord
  include AppendOnly

  TYPES = %w[opening invoice invoice_reversal payment payment_bounce credit_note credit_note_reversal
             adjustment purchase supplier_payment].freeze

  belongs_to :party, polymorphic: true
  belongs_to :document, polymorphic: true, optional: true
  belongs_to :user, optional: true

  validates :entry_type, inclusion: { in: TYPES }
  validates :entry_date, presence: true
  validate :one_side

  money :debit, :credit
  scope :chronological, -> { order(:entry_date, :id) }

  def amount_paise = debit_paise.positive? ? debit_paise : -credit_paise

  # Reverse this entry: same amount on the other side, same document.
  def reverse!(type:, narration:, date: Date.current)
    self.class.create!(party: party, document: document, entry_date: date, entry_type: type,
                       debit_paise: credit_paise, credit_paise: debit_paise, narration: narration)
  end

  private

  def one_side
    d, c = debit_paise.to_i, credit_paise.to_i
    errors.add(:base, "An entry is either a debit or a credit, above zero") unless d >= 0 && c >= 0 && (d.positive? ^ c.positive?)
  end
end
