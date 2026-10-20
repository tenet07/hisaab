class ShopSetting < ApplicationRecord
  money :eway_threshold, :writeoff_approval

  validates :name, :state_code, :invoice_prefix, presence: true
  validates :gstin, format: { with: Gstin::FORMAT, message: "isn't a valid GSTIN" }, allow_blank: true
  after_commit { self.class.instance_variable_set(:@current, nil) }

  def self.current
    first || create!
  end

  def state_name = GstStates::NAMES[state_code]
end
