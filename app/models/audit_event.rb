class AuditEvent < ApplicationRecord
  belongs_to :user, optional: true
  # the person a sync rejection belongs to is also its subject
  belongs_to :subject, polymorphic: true, optional: true

  def readonly? = persisted?
  scope :recent, -> { order(created_at: :desc) }

  def self.log!(subject, action, changeset = {})
    create!(subject: subject, action: action, changeset: changeset, user_id: Current.user&.id, device: Current.device)
  end
end
