class Replacement < ApplicationRecord
  belongs_to :customer
  belongs_to :product
  belongs_to :user
end
