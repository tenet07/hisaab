# The stock ledger. A product's stock in a bucket is the sum of its movements; nothing else stores it.
class StockMovement < ApplicationRecord
  include AppendOnly

  BUCKETS = %w[sellable awaiting_claim with_brand written_off].freeze
  BUCKET_LABELS = { "sellable" => "Sellable", "awaiting_claim" => "Awaiting claim",
                    "with_brand" => "With brand", "written_off" => "Written off" }.freeze
  REASONS = %w[opening purchase sale sale_reversal return replacement_out replacement_in claim_sent claim_replaced
               claim_credited claim_rejected write_off count_adjustment shortfall transfer].freeze

  belongs_to :product
  belongs_to :document, polymorphic: true, optional: true
  belongs_to :user, optional: true

  validates :bucket, inclusion: { in: BUCKETS }
  validates :reason, inclusion: { in: REASONS }
  validates :quantity, numericality: { other_than: 0, only_integer: true }

  scope :in_bucket, ->(b) { where(bucket: b) }
  scope :recent, -> { order(created_at: :desc, id: :desc) }

  # Post several movements together (a swap, a claim dispatch) — all or nothing.
  def self.post!(rows)
    transaction { rows.map { |r| create!(r) } }
  end

  # Quantities per [product_id, bucket]
  def self.balances = group(:product_id, :bucket).sum(:quantity)

  def inward? = quantity.positive?
end
