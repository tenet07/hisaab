# Who changed a master record, from which device, and what changed.
module Audited
  extend ActiveSupport::Concern

  included do
    after_create  { audit!("created", saved_changes.except("updated_at", "created_at")) }
    after_update  { audit!("updated", saved_changes.except("updated_at")) if saved_changes.except("updated_at").any? }
    after_destroy { audit!("deleted", attributes) }
  end

  private

  def audit!(action, changes)
    AuditEvent.create!(subject: self, action: action, changeset: changes.except("password_digest"),
                       user_id: Current.user&.id, device: Current.device)
  end
end
