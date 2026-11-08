class SupplierEntry < ApplicationRecord
  belongs_to :supplier
  belongs_to :user
  before_update { raise ActiveRecord::ReadOnlyRecord, "supplier entries are append-only" }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "supplier entries are append-only" }
end
