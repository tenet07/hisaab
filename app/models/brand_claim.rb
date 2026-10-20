# A batch of defective pieces sent to one brand under one challan, settled by the brand's
# credit note (possibly partial) and/or replacement pieces.
class BrandClaim < ApplicationRecord
  belongs_to :brand
  belongs_to :supplier, optional: true
  belongs_to :created_by, class_name: "User", optional: true
  has_many :replacements, dependent: :nullify
  has_many :stock_movements, as: :document
  money :credited
  before_validation(on: :create) { self.number ||= DocumentSequence.next!("brand_claim").first }
  scope :recent, -> { order(created_at: :desc) }
  scope :unsettled, -> { where(status: %w[open sent]) }

  def sent? = status == "sent"
  def settled? = status == "settled"
  def pieces = replacements.size
  def open_pieces = replacements.select(&:open?)
  def days_out = sent_on ? (Date.current - sent_on).to_i : 0

  # Sent long ago with nothing back from the brand: shown red on the claims screen.
  def flagged? = sent? && days_out > ShopSetting.current.claim_flag_days && open_pieces.size == pieces
  def expected_paise = replacements.sum { _1.product.purchase_paise }
end
