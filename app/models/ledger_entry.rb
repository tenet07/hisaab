class LedgerEntry < ApplicationRecord
  belongs_to :customer
  belongs_to :user
  before_update { raise ActiveRecord::ReadOnlyRecord, "ledger entries are append-only" }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "ledger entries are append-only" }
end
