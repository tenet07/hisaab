class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Money columns are integer paise. `money :total` gives #total (rupees, BigDecimal) and #total=.
  def self.money(*names)
    names.each do |n|
      define_method(n) { (self[:"#{n}_paise"] || 0).to_d / 100 }
      define_method(:"#{n}=") { |rupees| self[:"#{n}_paise"] = Money.to_paise(rupees) }
    end
  end
end
