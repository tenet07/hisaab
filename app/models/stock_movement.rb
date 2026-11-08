class StockMovement < ApplicationRecord
  belongs_to :product
  belongs_to :user
  validates :bucket, inclusion: { in: Shop::BUCKETS.map(&:to_s) }
  before_update { raise ActiveRecord::ReadOnlyRecord, "stock movements are append-only" }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "stock movements are append-only" }
end
