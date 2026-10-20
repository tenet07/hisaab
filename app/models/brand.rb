class Brand < ApplicationRecord
  include Audited
  has_many :products, dependent: :restrict_with_error
  has_many :brand_claims, dependent: :restrict_with_error
  has_many :suppliers, dependent: :nullify

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :warranty_months, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  default_scope { order(:name) }
end
