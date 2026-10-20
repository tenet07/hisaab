class Delivery < ApplicationRecord
  STATUSES = %w[pending delivered partial failed].freeze
  belongs_to :dispatch_run
  belongs_to :invoice
  belongs_to :delivered_by, class_name: "User", optional: true
  has_one_attached :photo
  validates :status, inclusion: { in: STATUSES }
  before_create { self.otp_code ||= format("%04d", SecureRandom.random_number(10_000)) }
  delegate :customer, to: :invoice
  def done? = %w[delivered partial].include?(status)
  def failed? = status == "failed"
  def closed? = status != "pending"
end
