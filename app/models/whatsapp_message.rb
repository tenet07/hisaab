class WhatsappMessage < ApplicationRecord
  belongs_to :customer, optional: true
  belongs_to :document, polymorphic: true, optional: true
  has_one_attached :attachment
  scope :recent, -> { order(created_at: :desc, id: :desc) }
  scope :outbound, -> { where(direction: "out") }
  scope :inbound, -> { where(direction: "in") }
  def outbound? = direction == "out"
end
