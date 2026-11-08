# The shop's own details: printed on bills, used for GST and Tally.
# Exactly one row per database (one database per shop when serving several).
class ShopSetting < ApplicationRecord
  TALLY_KEYS = Shop::TallyExport::DEFAULT_LEDGERS.keys.map(&:to_s).freeze

  validates :name, presence: true
  validates :state_code, inclusion: { in: Shop::STATES.keys, message: "pick a state" }
  validates :gstin, format: { with: /\A\d{2}[A-Z0-9]{13}\z/, message: "is not a valid GSTIN" }, allow_blank: true
  # Bill numbers are PREFIX/YY-YY/NNNNN: GST allows at most 16 characters.
  validates :invoice_prefix, :credit_note_prefix, format: { with: /\A[A-Z0-9]{1,4}\z/, message: "must be 1 to 4 letters or digits" }
  validate :prefixes_differ
  validates :upi_id, format: { with: /\A[\w.\-]{2,256}@[a-zA-Z][a-zA-Z0-9.]{2,64}\z/, message: "looks wrong (example: shopname@okhdfcbank)" }, allow_blank: true
  validates :bank_ifsc, format: { with: /\A[A-Z]{4}0[A-Z0-9]{6}\z/, message: "should look like HDFC0001234" }, allow_blank: true

  before_validation do
    self.gstin = gstin.to_s.upcase.strip.presence
    self.state_code = gstin[0, 2] if gstin.present?
    self.invoice_prefix = invoice_prefix.to_s.upcase.strip
    self.credit_note_prefix = credit_note_prefix.to_s.upcase.strip
    self.bank_ifsc = bank_ifsc.to_s.upcase.strip.presence
    self.upi_id = upi_id.to_s.strip.presence
  end
  after_save { Current.settings = nil }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "shop settings can't be deleted" }

  def self.current = Current.settings ||= (first || create!)

  def state_name = Shop::STATES[state_code]
  def ledgers = Shop::TallyExport::DEFAULT_LEDGERS.merge((tally_ledgers || {}).transform_keys(&:to_sym).compact_blank)
  def address_lines = address.to_s.lines.map(&:strip).reject(&:empty?)

  private

  def prefixes_differ
    errors.add(:credit_note_prefix, "must be different from the bill prefix") if invoice_prefix == credit_note_prefix
  end
end
