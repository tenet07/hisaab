# Ledger rows are written once. The database enforces it too (forbid_ledger_change trigger);
# this just fails earlier with a clearer message. Corrections are new, reversing rows.
module AppendOnly
  extend ActiveSupport::Concern

  included do
    before_create { self.device ||= Current.device; self.user_id ||= Current.user&.id }
  end

  def readonly? = persisted? || super
  def destroy = raise(ActiveRecord::ReadOnlyRecord, "#{self.class.name} is append-only: post a reversing entry")
  def delete = destroy
end
