class Order < ApplicationRecord
  CHANNELS = %w[whatsapp salesman counter].freeze
  STATUSES = %w[draft confirmed invoiced cancelled].freeze

  belongs_to :customer
  belongs_to :created_by, class_name: "User", optional: true
  has_many :lines, class_name: "OrderLine", dependent: :destroy, inverse_of: :order
  has_one :invoice
  has_many :whatsapp_messages, as: :document

  accepts_nested_attributes_for :lines, allow_destroy: true, reject_if: ->(a) { a[:product_id].blank? && a[:quantity].blank? }
  validates :channel, inclusion: { in: CHANNELS }
  validates :status, inclusion: { in: STATUSES }
  before_validation(on: :create) { self.number ||= DocumentSequence.next!("order").first }

  scope :open, -> { where(status: %w[draft confirmed]) }
  scope :recent, -> { order(created_at: :desc) }

  def draft? = status == "draft"
  def confirmed? = status == "confirmed"
  def editable? = %w[draft confirmed].include?(status)
  def needs_review? = lines.any? { _1.product_id.nil? || _1.confidence.to_f < 0.75 }
  def estimate_paise = lines.sum { _1.product ? _1.quantity * _1.effective_rate_paise * (100 - _1.discount_pct) / 100 : 0 }.round

  def confirm!
    raise ArgumentError, "Every line needs a product" if lines.any? { _1.product_id.nil? }
    update!(status: "confirmed")
  end
end
