class Current < ActiveSupport::CurrentAttributes
  attribute :session, :device
  delegate :user, to: :session, allow_nil: true

  # Who/which device every ledger row and audit event is stamped with.
  def stamp = { user_id: user&.id, device: device }
end
