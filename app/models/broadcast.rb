class Broadcast < ApplicationRecord
  belongs_to :created_by, class_name: "User", optional: true
  validates :title, :body, presence: true
  validates :body, length: { maximum: 1000 }

  # Only customers who opted in to marketing messages (Meta policy; plan §WhatsApp)
  def audience
    scope = Customer.active.where(marketing_opt_in: true)
    market_ids.any? ? scope.where(market_id: market_ids) : scope
  end

  def sent? = status == "sent"
end
