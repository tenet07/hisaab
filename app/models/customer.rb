class Customer < ApplicationRecord
  include Audited
  TIERS = %w[wholesale retail mrp].freeze

  belongs_to :market, optional: true
  has_many :ledger_entries, as: :party
  has_many :orders, dependent: :restrict_with_error
  has_many :invoices, dependent: :restrict_with_error
  has_many :payments, dependent: :restrict_with_error
  has_many :credit_notes, dependent: :restrict_with_error
  has_many :replacements, dependent: :restrict_with_error
  has_many :whatsapp_messages, dependent: :nullify

  money :credit_limit
  validates :code, presence: true, uniqueness: { case_sensitive: false }
  validates :shop_name, presence: true
  validates :phone, presence: true, format: { with: /\A91\d{10}\z/, message: "must be a 10-digit Indian mobile" }
  validates :price_tier, inclusion: { in: TIERS }
  validate :gstin_checksum
  normalizes :phone, with: ->(p) { d = p.to_s.gsub(/\D/, ""); d.length == 10 ? "91#{d}" : d }
  normalizes :gstin, with: ->(g) { g.to_s.strip.upcase.presence }
  normalizes :code, with: ->(c) { c.strip.upcase }
  before_validation { self.state_code = Gstin.state_code(gstin) if gstin.present? }
  before_validation(on: :create) { self.code = self.class.next_code if code.blank? }

  scope :active, -> { where(active: true) }
  scope :search, ->(q) {
    next all if q.blank?
    t = "%#{sanitize_sql_like(q.strip)}%"
    where("shop_name ILIKE :t OR owner_name ILIKE :t OR code ILIKE :t OR phone LIKE :d OR gstin ILIKE :t",
          t: t, d: "%#{q.gsub(/\D/, '').presence || '~'}%")
  }

  BALANCE_SQL = "COALESCE((SELECT SUM(debit_paise - credit_paise) FROM ledger_entries le " \
                "WHERE le.party_type = 'Customer' AND le.party_id = customers.id), 0)".freeze
  scope :with_balance, -> { select("customers.*, #{BALANCE_SQL} AS balance_paise_sql") }

  def self.next_code
    n = where("code ~ '^C[0-9]+$'").pluck(:code).map { _1[1..].to_i }.max.to_i + 1
    "C#{n.to_s.rjust(4, '0')}"
  end

  def self.find_by_phone(raw)
    d = raw.to_s.gsub(/\D/, "")
    d = "91#{d}" if d.length == 10
    find_by(phone: d)
  end

  # ── ledger-derived figures ──
  def balance_paise
    return self[:balance_paise_sql].to_i if has_attribute?(:balance_paise_sql)
    ledger_entries.sum("debit_paise - credit_paise").to_i
  end

  def balance_on(date) = ledger_entries.where(entry_date: ..date).sum("debit_paise - credit_paise").to_i

  # unpaid bills and unpaid opening balance, oldest first
  def open_items = @open_items ||= Receivables.open_items([id])
  def open_invoices = open_items.grep(Invoice)
  def oldest_unpaid = open_items.first
  def overdue_paise(on = Date.current) = open_items.select { _1.due_date < on }.sum(&:outstanding_paise)

  # Payments not yet matched to an invoice (paid in advance or more than was due)
  def unallocated_paise
    payments.cleared.sum(:amount_paise) - PaymentAllocation.joins(:payment).where(payments: { customer_id: id, status: "cleared" }).sum(:amount_paise)
  end

  def ageing(on = Date.current)
    open_items.each_with_object(Receivables.empty_ageing) { |i, b| b[Receivables.ageing_bucket(i, on)] += i.outstanding_paise }
  end

  # Walk-in and retail-tier customers are quoted MRP-style prices that include GST;
  # dealers on the wholesale rate list are billed rate + GST, at the counter or anywhere else.
  def prices_include_tax? = !b2b? && price_tier != "wholesale"

  def over_credit_limit?(extra_paise = 0) = credit_limit_paise.positive? && balance_paise + extra_paise > credit_limit_paise
  def interstate? = state_code.present? && state_code != ShopSetting.current.state_code
  def b2b? = gstin.present?
  def display_phone = phone.to_s.sub(/\A91(\d{5})(\d{5})\z/, '+91 \1 \2')
  def label = "#{shop_name} · #{market&.name || 'No market'}"

  private

  def gstin_checksum
    errors.add(:gstin, "checksum doesn't match — check for a typo") if gstin.present? && !Gstin.valid?(gstin)
  end
end
