# A defective piece brought back by a customer. The piece itself moves through stock buckets:
# awaiting_claim → with_brand → (replaced: back to sellable | credited / rejected / written_off).
class Replacement < ApplicationRecord
  OUTCOMES = { "swapped" => "Swapped from stock", "charged" => "Out of warranty — new piece billed",
               "returned" => "Returned to customer unrepaired" }.freeze
  CLAIM_STATUSES = %w[awaiting with_brand replaced credited rejected written_off none].freeze

  belongs_to :customer
  belongs_to :product
  belongs_to :invoice, optional: true
  belongs_to :brand_claim, optional: true
  belongs_to :logged_by, class_name: "User", optional: true
  has_many :stock_movements, as: :document
  has_many :approvals, as: :subject
  money :credited

  validates :outcome, inclusion: { in: OUTCOMES.keys }
  validates :claim_status, inclusion: { in: CLAIM_STATUSES }
  before_validation(on: :create) { self.number ||= DocumentSequence.next!("replacement").first }

  scope :open_claims, -> { where(claim_status: %w[awaiting with_brand]) }
  scope :awaiting, -> { where(claim_status: "awaiting") }
  scope :recent, -> { order(created_at: :desc) }

  def open? = %w[awaiting with_brand].include?(claim_status)
  def status_label = claim_status.humanize
end
