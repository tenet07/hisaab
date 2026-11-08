class ClaimCredit < ApplicationRecord
  belongs_to :claim
  belongs_to :supplier
  belongs_to :user
end
