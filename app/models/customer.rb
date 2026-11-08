class Customer < ApplicationRecord
  # The shop's GST state, from Shop settings.
  def self.shop_state = ShopSetting.current.state_code
  belongs_to :market
  has_many :invoices, dependent: :restrict_with_error
  has_many :ledger_entries, dependent: :restrict_with_error
  has_many :payments, dependent: :restrict_with_error
  has_many :replacements, dependent: :restrict_with_error

  validates :name, presence: true
  validates :price_tier, inclusion: { in: %w[retail wholesale] }
  validates :phone, format: { with: /\A\d{10}\z/, message: "must be 10 digits" }, allow_blank: true
  validates :gstin, format: { with: /\A\d{2}[A-Z0-9]{13}\z/, message: "is not a valid GSTIN" }, allow_blank: true
  before_validation do
    if gstin.present? then self.state_code = gstin[0, 2]
    elsif new_record? && !state_code_changed? then self.state_code = Customer.shop_state
    end
  end

  def intra_state? = state_code == Customer.shop_state
  def state_name = Shop::STATES[state_code]
  def balance_paise = ledger_entries.sum("debit_paise - credit_paise")

  def core_ledger
    led = Shop::CustomerLedger.new
    ledger_entries.order(:date, :id).each do |e|
      led.entries << Shop::Entry.new(customer_id: id, date: e.date, kind: e.kind.to_sym, ref: e.ref,
                                     debit: e.debit_paise, credit: e.credit_paise, by: e.user_id)
    end
    led
  end

  def open_items = core_ledger.open_items(id)
  def ageing(as_of = Date.current) = core_ledger.ageing(id, as_of: as_of)
  def over_limit? = credit_limit_paise.positive? && balance_paise > credit_limit_paise
  def whatsapp_number = phone.present? ? "91#{phone}" : nil
end
