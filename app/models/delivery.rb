class Delivery < ApplicationRecord
  STATUSES = %w[pending loaded delivered partly_delivered failed cancelled].freeze
  OPEN = %w[pending loaded].freeze
  belongs_to :invoice
  belongs_to :assigned_to, class_name: "User", optional: true
  has_many :items, class_name: "DeliveryItem", dependent: :destroy
  has_many :payments
  has_many :credit_notes
  has_one :customer, through: :invoice
  validates :status, inclusion: { in: STATUSES }

  scope :open, -> { where(status: OPEN) }
  scope :for_run, ->(date) { where(run_date: date) }

  def open? = OPEN.include?(status)
  def done? = %w[delivered partly_delivered].include?(status)
  def self.new_otp = format("%04d", SecureRandom.random_number(10_000))
end
