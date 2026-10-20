class InvoicesController < ApplicationController
  include LineItems
  require_permission :invoices
  before_action :require_writer!, except: %i[index show]
  before_action :set_invoice, only: %i[show cancel send_whatsapp eway]

  def index
    scope = Invoice.with_outstanding.includes(:customer).recent
    # counter staff see the bills they made this week, to reprint — not everyone's dues
    scope = scope.where(posted_by: Current.user, invoice_date: 7.days.ago.to_date..) unless can?(:ledgers)
    @from = params[:from].presence && date_param(params[:from])
    @to = params[:to].presence && date_param(params[:to])
    scope = scope.where(invoice_date: @from..) if @from
    scope = scope.where(invoice_date: ..@to) if @to
    scope = scope.where(customer_id: params[:customer_id]) if params[:customer_id].present?
    scope = scope.joins(:customer).where(customers: { market_id: params[:market_id] }) if params[:market_id].present?
    scope = scope.where("invoices.number ILIKE :q OR invoices.bill_to_name ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?
    scope = scope.where(status: "cancelled") if params[:state] == "cancelled"
    scope = scope.where(eway_required: true, eway_bill_no: nil).posted if params[:state] == "eway"
    invoices = scope.limit(500).to_a
    invoices.select!(&:overdue?) if params[:state] == "overdue"
    invoices.select!(&:unpaid?) if params[:state] == "unpaid"
    @invoices = invoices.first(200)
    @totals = { total: @invoices.select(&:posted?).sum(&:total_paise), due: @invoices.sum(&:outstanding_paise) }
  end

  def show
    raise Forbidden unless can?(:ledgers) || @invoice.posted_by_id == Current.user.id || @invoice.customer.code == "CASH"
    @invoice.lines.load
    respond_to do |f|
      f.html
      f.pdf { send_data InvoicePdf.new(@invoice).render, filename: "#{@invoice.number.tr('/', '-')}.pdf", type: "application/pdf", disposition: "inline" }
    end
  end

  def new
    authorize!(:invoice_post)
    @customer = Customer.find_by(id: params[:customer_id])
  end

  def create
    authorize!(:invoice_post)
    customer = Customer.find(params.require(:customer_id))
    raise ArgumentError, "Walk-in sales are billed and paid at the counter screen" if customer.code == "CASH"
    items = line_items(params[:lines], customer: customer)
    if (msg = credit_hold(customer, items))
      raise ArgumentError, msg
    end
    if over_discount_limit?(items, customer) && !Current.user.owner?
      raise ArgumentError, "A discount is above #{shop.discount_approval_pct.to_f}%. Save it as an order — the owner approves it from the queue."
    end
    inv = Invoicing::Post.call(customer: customer, items: items, date: can_set_rates? ? date_param(params[:invoice_date]) : Date.current,
                               channel: params[:channel].presence || "counter", allow_negative_stock: params[:allow_negative] == "1" && Current.user.owner?)
    WhatsappNotifier.invoice(inv) if params[:whatsapp] == "1"
    redirect_to inv, notice: "Invoice #{inv.number} posted."
  end

  def cancel
    authorize!(:invoice_cancel)
    Invoicing::Cancel.call(@invoice, reason: params[:reason])
    redirect_to @invoice, notice: "Invoice cancelled. Stock and the customer's ledger were reversed."
  end

  def send_whatsapp
    WhatsappNotifier.invoice(@invoice)
    redirect_to @invoice, notice: "Invoice sent to #{@invoice.customer.display_phone} on WhatsApp."
  end

  def eway
    authorize!(:invoice_cancel)
    @invoice.update!(eway_bill_no: params[:eway_bill_no].to_s.strip.presence)
    AuditEvent.log!(@invoice, "eway_bill", { "eway_bill_no" => @invoice.eway_bill_no })
    redirect_to @invoice, notice: "E-way bill number saved."
  end

  private

  def set_invoice = @invoice = Invoice.find(params[:id])
end
