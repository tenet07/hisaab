class InvoicesController < ApplicationController
  before_action :require_billing!, only: %i[new create]

  def index
    @date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    @invoices = Invoice.includes(customer: :market).where(date: @date).order(:number)
  end

  def new
    @customer = Customer.find_by(id: params[:customer_id])
    @customers = Customer.order(:name)
    @products = Product.order(:brand, :name)
    @balances = LedgerEntry.group(:customer_id).sum("debit_paise - credit_paise") # presentation only
  end

  def create
    customer = Customer.find(params[:customer_id])
    rows = params[:items].respond_to?(:values) ? params[:items].values : Array(params[:items])
    items = rows.map do |i|
      next if i[:product_id].blank?
      { product: Product.find(i[:product_id]), qty: i[:qty].to_i, discount_paise: paise(i[:discount]) }
    end.compact
    inv = Books.create_invoice(customer: customer, items: items, user: current_user,
                               channel: current_user.field? ? "salesman" : "counter",
                               deliver: params[:deliver] == "1")
    redirect_to inv, notice: "Bill #{inv.number} saved"
  end

  def show
    @invoice = Invoice.includes(lines: :product).find(params[:id])
    render layout: "print" if params[:print]
  end

  def cancel
    inv = Invoice.find(params[:id])
    Books.cancel_invoice(inv, user: current_user, reason: params[:reason])
    redirect_to inv, notice: "Bill cancelled; stock and balance reversed"
  end

  private

  def require_billing!
    redirect_to root_path, alert: "Your role can't make bills" unless current_user.can_bill?
  end
end
