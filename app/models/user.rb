class User < ApplicationRecord
  ROLES = %w[owner accounts counter salesman delivery ca].freeze

  # What each role may do. Anything not listed is refused (see ApplicationController#authorize!).
  PERMISSIONS = {
    "owner"    => :all,
    "accounts" => %i[dashboard orders invoices invoice_post invoice_cancel credit_notes payments payments_bounce ledgers
                     customers customers_edit products products_edit stock purchases replacements claims claims_edit
                     dispatch counts reports exports whatsapp approvals_request audit margins],
    "counter"  => %i[orders invoices invoice_post payments stock_lookup replacements customers products counter_pos],
    "salesman" => %i[mobile visits orders payments replacements stock_lookup],
    "delivery" => %i[mobile route deliveries payments],
    "ca"       => %i[dashboard invoices credit_notes payments ledgers customers products stock purchases reports exports audit margins]
  }.freeze

  ROLE_LABELS = {
    "owner" => "Owner", "accounts" => "Accounts", "counter" => "Counter staff",
    "salesman" => "Salesman", "delivery" => "Delivery", "ca" => "CA (read-only)"
  }.freeze

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :markets, foreign_key: :salesman_id, inverse_of: :salesman

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true
  validates :role, inclusion: { in: ROLES }

  scope :active, -> { where(active: true) }
  scope :with_role, ->(r) { where(role: r) }

  ROLES.each { |r| define_method(:"#{r}?") { role == r } }

  def can?(permission)
    perms = PERMISSIONS.fetch(role, [])
    perms == :all || perms.include?(permission.to_sym)
  end

  # Field staff live in the phone app; everyone else in the desktop console.
  def mobile_first? = salesman? || delivery?
  def read_only? = ca?
  def role_label = ROLE_LABELS[role]
  def initials = name.split.map(&:first).first(2).join.upcase
end
