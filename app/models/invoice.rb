class Invoice < ApplicationRecord
  belongs_to :customer
  belongs_to :created_by, class_name: "User"
  has_many :lines, class_name: "InvoiceLine", dependent: :restrict_with_error
  has_one :delivery, dependent: :restrict_with_error
  has_many :credit_notes, dependent: :restrict_with_error
  scope :posted, -> { where(status: "posted") }

  def cancelled? = status == "cancelled"
  def tax_paise = cgst_paise + sgst_paise + igst_paise
  def needs_eway_bill? = total_paise > Shop::Invoice::E_WAY_BILL_THRESHOLD

  # Rebuild the core invoice (used by Tally export and as a cross-check).
  def to_core
    Shop::Invoice.new(number: number, date: date, customer_id: customer_id, intra_state: intra_state,
                      lines: lines.includes(:product).map(&:to_core))
  end

  def self.seller_snapshot
    s = ShopSetting.current
    s.slice(:name, :address, :phone, :email, :gstin, :state_code, :upi_id, :bank_name, :bank_account, :bank_ifsc, :bill_terms)
  end

  def self.buyer_snapshot(c)
    c.slice(:name, :owner_name, :phone, :gstin, :address, :state_code)
  end

  # Details as printed on the bill (snapshot), falling back for bills made before snapshots existed.
  def seller_details = (seller.presence || Invoice.seller_snapshot).with_indifferent_access
  def buyer_details = (buyer.presence || Invoice.buyer_snapshot(customer)).with_indifferent_access
  def place_of_supply = buyer_details[:state_code]

  # Tax by HSN and rate, split exactly as the bill was taxed.
  def hsn_tax_summary
    to_core.lines.group_by { |t| [t.line.hsn, t.line.gst_bp] }.map do |(hsn, bp), ts|
      { hsn: hsn, gst_bp: bp, taxable: ts.sum(&:taxable), cgst: ts.sum(&:cgst), sgst: ts.sum(&:sgst), igst: ts.sum(&:igst) }
    end.sort_by { |r| r[:hsn] }
  end

  def self.next_number(date)
    fy = date.month >= 4 ? date.year : date.year - 1
    prefix = "#{ShopSetting.current.invoice_prefix}/#{fy % 100}-#{(fy + 1) % 100}/"
    last = where("number LIKE ?", "#{prefix}%").maximum(:number)
    seq = last ? last.split("/").last.to_i + 1 : 1
    "#{prefix}#{seq.to_s.rjust(5, '0')}"
  end
end
