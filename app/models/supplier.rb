class Supplier < ApplicationRecord
  has_many :purchase_bills, dependent: :restrict_with_error
  has_many :entries, class_name: "SupplierEntry", dependent: :restrict_with_error
  has_many :payments, class_name: "SupplierPayment", dependent: :restrict_with_error
  has_many :claims
  has_many :claim_credits

  validates :name, presence: true, uniqueness: true
  validates :gstin, format: { with: /\A\d{2}[A-Z0-9]{13}\z/, message: "is not a valid GSTIN" }, allow_blank: true
  before_validation do
    self.gstin = gstin.to_s.upcase.strip.presence
    if gstin.present? then self.state_code = gstin[0, 2]
    elsif new_record? && !state_code_changed? then self.state_code = Customer.shop_state
    end
    self.brands = brand_list.join(", ")
  end

  def brand_list = brands.to_s.split(",").map(&:strip).reject(&:empty?).uniq(&:downcase)
  def intra_state? = state_code == Customer.shop_state
  def payable_paise = entries.sum("credit_paise - debit_paise")

  # Who to claim from / who credits a claim for this brand.
  def self.for_brand(brand)
    all.find { |s| s.brand_list.map(&:downcase).include?(brand.to_s.downcase) }
  end

  # What is still owed, oldest first: the opening balance, then purchase bills.
  # Payments and brand credits clear the oldest item first.
  def unpaid_bills
    items = entries.where(kind: "opening").where("credit_paise > 0").order(:date).map do |e|
      { bill: nil, ref: "Opening balance", date: e.date, amount: e.credit_paise, due_on: e.date + credit_days }
    end
    items += purchase_bills.order(:date, :id).map do |b|
      { bill: b, ref: b.number, date: b.date, amount: b.total_paise, due_on: b.date + credit_days }
    end
    pool = entries.sum(:debit_paise)
    items.filter_map do |i|
      used = [pool, i[:amount]].min
      pool -= used
      due = i[:amount] - used
      i.merge(due: due) if due.positive?
    end
  end
end
