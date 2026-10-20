class Invoice < ApplicationRecord
  belongs_to :customer
  belongs_to :order, optional: true
  belongs_to :posted_by, class_name: "User", optional: true
  belongs_to :cancelled_by, class_name: "User", optional: true
  has_many :lines, class_name: "InvoiceLine", dependent: :restrict_with_error, inverse_of: :invoice
  has_many :payment_allocations, dependent: :restrict_with_error
  has_many :credit_notes, dependent: :restrict_with_error
  has_many :ledger_entries, as: :document
  has_many :stock_movements, as: :document
  has_one :delivery
  has_many :whatsapp_messages, as: :document

  money :taxable, :cgst, :sgst, :igst, :round_off, :total
  scope :posted, -> { where(status: "posted") }
  scope :recent, -> { order(invoice_date: :desc, id: :desc) }
  scope :in_fy, ->(fy) { where(fy: fy) }
  scope :between, ->(r) { where(invoice_date: r) }
  scope :undispatched, -> { posted.where.missing(:delivery) }

  def posted? = status == "posted"
  def cancelled? = status == "cancelled"
  def tax_paise = cgst_paise + sgst_paise + igst_paise
  def interstate? = igst_paise.positive? || place_of_supply != ShopSetting.current.state_code
  def b2b? = bill_to_gstin.present?

  def paid_paise = payment_allocations.sum(:amount_paise)
  def credited_paise = credit_notes.sum(:total_paise)
  def outstanding_paise = posted? ? [total_paise - paid_paise - credited_paise, 0].max : 0
  def unpaid? = outstanding_paise.positive?
  def overdue?(on = Date.current) = unpaid? && due_date < on
  def days_overdue(on = Date.current) = overdue?(on) ? (on - due_date).to_i : 0

  def payment_state
    return "cancelled" if cancelled?
    return "paid" unless unpaid?
    return "overdue" if overdue?
    paid_paise.positive? || credited_paise.positive? ? "part-paid" : "unpaid"
  end

  # Lines already credited back, per invoice line
  def credited_qty_by_line = CreditNoteLine.joins(:credit_note).where(credit_notes: { invoice_id: id }).group(:invoice_line_id).sum(:quantity)

  def hsn_summary
    lines.group_by { [_1.hsn, _1.gst_rate] }.map do |(hsn, rate), ls|
      { hsn: hsn, rate: rate, qty: ls.sum(&:quantity), taxable: ls.sum(&:taxable_paise),
        cgst: ls.sum(&:cgst_paise), sgst: ls.sum(&:sgst_paise), igst: ls.sum(&:igst_paise) }
    end
  end

  def upi_uri
    s = ShopSetting.current
    return if s.upi_id.blank? || outstanding_paise.zero?
    "upi://pay?pa=#{s.upi_id}&pn=#{ERB::Util.url_encode(s.name)}&am=#{format('%.2f', outstanding_paise / 100.0)}&tn=#{ERB::Util.url_encode(number)}&cu=INR"
  end
end
