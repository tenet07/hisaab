class Approval < ApplicationRecord
  KINDS = { "write_off" => "Write off defective stock", "discount" => "Discount above limit",
            "credit_limit" => "Bill over credit limit", "stock_adjustment" => "Stock count adjustment" }.freeze

  belongs_to :subject, polymorphic: true
  belongs_to :requested_by, class_name: "User", optional: true
  belongs_to :decided_by, class_name: "User", optional: true
  money :amount
  scope :pending, -> { where(status: "pending") }
  scope :recent, -> { order(created_at: :desc) }

  def pending? = status == "pending"
  def approved? = status == "approved"
  def kind_label = KINDS[kind]
end
