class Claim < ApplicationRecord
  belongs_to :user
  belongs_to :supplier, optional: true
  has_many :lines, class_name: "ClaimLine", dependent: :restrict_with_error
  has_many :credits, class_name: "ClaimCredit", dependent: :restrict_with_error
  def open_qty = lines.sum(&:open_qty)
  def credit_qty = lines.sum(&:settled_credit_qty)
  def credited_paise = credits.sum(:amount_paise)
  # What the credited pieces cost us (latest purchase rate incl. GST), as a guide.
  def expected_credit_paise = lines.sum { |l| l.settled_credit_qty * l.product.last_cost_paise }
end
