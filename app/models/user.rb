class User < ApplicationRecord
  ROLES = %w[owner accounts counter salesman delivery].freeze
  has_secure_password
  # PIN: 4 to 6 digits, and not something guessable like 1234 or 0000 (except in demo data).
  WEAK = %w[0000 1111 2222 3333 4444 5555 6666 7777 8888 9999 1234 4321 123456 000000].freeze
  validate :pin_shape, if: -> { password.present? }
  def pin_shape
    errors.add(:base, "PIN must be 4 to 6 digits") unless password.match?(/\A\d{4,6}\z/)
    errors.add(:base, "PIN is too easy to guess") if WEAK.include?(password) && !Rails.env.development? && !Rails.env.test? && ENV["DEMO_DATA"] != "1"
  end
  validates :name, presence: true, uniqueness: true
  validates :role, inclusion: { in: ROLES }
  scope :active, -> { where(active: true) }

  # A 4-digit PIN has only 10,000 combinations, so on the internet it needs a lock:
  # 5 wrong PINs in a row lock that login for 15 minutes. A new PIN unlocks it.
  MAX_TRIES = 5
  LOCK_FOR = 15.minutes
  before_save(if: :password_digest_changed?) { self.failed_pins = 0; self.locked_until = nil }

  def locked? = locked_until.present? && locked_until.future?
  def pin_failed!
    tries = failed_pins + 1
    update_columns(failed_pins: tries >= MAX_TRIES ? 0 : tries, locked_until: tries >= MAX_TRIES ? LOCK_FOR.from_now : locked_until)
  end
  def pin_ok! = (update_columns(failed_pins: 0, locked_until: nil) if failed_pins.positive? || locked_until)

  def owner? = role == "owner"
  def office? = %w[owner accounts counter].include?(role)
  def field? = %w[salesman delivery].include?(role)
  def delivery? = role == "delivery"
  def can_bill? = %w[owner accounts counter salesman].include?(role)
end
