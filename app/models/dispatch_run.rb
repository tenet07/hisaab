class DispatchRun < ApplicationRecord
  belongs_to :market
  belongs_to :delivery_person, class_name: "User", optional: true
  has_many :deliveries, -> { order(:position, :id) }, dependent: :restrict_with_error
  has_many :invoices, through: :deliveries
  validates :run_date, uniqueness: { scope: :market_id, message: "already has a run for this market" }
  scope :for_date, ->(d) { where(run_date: d) }

  def progress = [deliveries.count { _1.status != "pending" }, deliveries.size]
  def cash_collected_paise
    Payment.where(collected_by: delivery_person, received_on: run_date, mode: "cash",
                  customer_id: deliveries.map { _1.invoice.customer_id }).sum(:amount_paise)
  end
end
