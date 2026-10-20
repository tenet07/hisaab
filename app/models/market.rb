class Market < ApplicationRecord
  include Audited
  WEEKDAYS = Date::DAYNAMES

  belongs_to :salesman, class_name: "User", optional: true
  has_many :customers, dependent: :restrict_with_error
  has_many :dispatch_runs, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  default_scope { order(:position, :name) }

  def delivery_day = delivery_weekday && WEEKDAYS[delivery_weekday]
  def today? = delivery_weekday == Date.current.wday
end
