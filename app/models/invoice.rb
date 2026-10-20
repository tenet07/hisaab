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

  OUTSTANDING_SQL = "(invoices.total_paise - COALESCE((SELECT SUM(pa.amount_paise) FROM payment_allocations pa WHERE pa.invoice_id = invoices.id), 0) " \
                    "- COALESCE((SELECT SUM(cn.total_paise) FROM credit_notes cn WHERE cn.invoice_id = invoices.id), 0))".freeze
  PAID_SQL = "COALESCE((SELECT SUM(pa.amount_paise) FROM payment_allocations pa WHERE pa.invoice_id = invoices.id), 0)".freeze
  scope :with_outstanding, -> { select("invoices.*, #{OUTSTANDING_SQL} AS outstanding_sql, #{PAID_SQL} AS paid_sql") }
  scope :unpaid, -> { where(status: "posted").where("#{OUTSTANDING_SQL} > 0") }
  scope :posted, -> { where(status: "posted") }
  scope :recent, -> { order(invoice_date: :desc, id: :desc) }
  scope :in_fy, ->(fy) { where(fy: fy) }
  scope :between, ->(r) { where(invoice_date: r) }
  # not on any route yet, or its last delivery attempt failed
  scope :undispatched, -> { posted.left_joins(:delivery).where(deliveries: { id: nil }).or(posted.left_joins(:delivery).where(deliveries: { status: "failed" })) }

  def posted? = status == "posted"
  def cancelled? = status == "cancelled"
  def tax_paise = cgst_paise + sgst_paise + igst_paise
  def interstate? = igst_paise.positive? || place_of_supply != ShopSetting.current.state_code
  def b2b? = bill_to_gstin.present?

  def paid_paise = has_attribute?(:paid_sql) ? self[:paid_sql].to_i : payment_allocations.sum(:amount_paise)
  def credited_paise = credit_notes.sum(:total_paise)

  def outstanding_paise
    return 0 unless posted?
    return [self[:outstanding_sql].to_i, 0].max if has_attribute?(:outstanding_sql)
    [total_paise - paid_paise - credited_paise, 0].max
  end
  def unpaid? = outstanding_paise.positive?
  def overdue?(on = Date.current) = unpaid? && due_date < on
  def days_overdue(on = Date.current) = overdue?(on) ? (on - due_date).to_i : 0

  def payment_state
    return "cancelled" if cancelled?
    return "paid" unless unpaid?
    return "overdue" if overdue?
    outstanding_paise < total_paise ? "part-paid" : "unpaid"
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
