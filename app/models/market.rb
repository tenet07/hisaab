class Market < ApplicationRecord
  belongs_to :salesman, class_name: "User", optional: true
  belongs_to :delivery_person, class_name: "User", optional: true
  has_many :customers, dependent: :restrict_with_error
  validates :name, presence: true, uniqueness: true
end
