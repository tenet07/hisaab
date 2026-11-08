class ClaimLine < ApplicationRecord
  belongs_to :claim
  belongs_to :product
  def open_qty = qty - settled_new_qty - settled_credit_qty - rejected_qty
end
