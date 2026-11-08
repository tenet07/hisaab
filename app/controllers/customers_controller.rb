class CustomersController < ApplicationController
  before_action :require_office!, only: %i[new create edit update]
  before_action :set_customer, only: %i[show edit update visit statement]

  def index
    @markets = Market.order(:name)
    @market = @markets.find_by(id: params[:market_id])
    scope = Customer.includes(:market).order(:name)
    scope = scope.where(market: @market) if @market
    scope = scope.where("customers.name LIKE :q OR phone LIKE :q", q: "%#{params[:q]}%") if params[:q].present?
    @customers = scope
    @balances = LedgerEntry.group(:customer_id).sum("debit_paise - credit_paise")
  end

  def show
    @entries = @customer.ledger_entries.includes(:user).order(:date, :id)
    @open = @customer.open_items
    @ageing = @customer.ageing
  end

  # The salesman's screen on entering a shop.
  def visit
    @open = @customer.open_items
    @recent = @customer.invoices.posted.order(date: :desc, id: :desc).limit(3)
    @replacements = @customer.replacements.includes(:product).order(created_at: :desc).limit(5)
    @last_payment = @customer.payments.order(date: :desc, id: :desc).first
  end

  def statement
    @entries = @customer.ledger_entries.order(:date, :id)
    render layout: "print"
  end

  def new = @customer = Customer.new(price_tier: "wholesale")
  def edit; end

  def create
    @customer = Customer.new(customer_params)
    Customer.transaction do
      @customer.save!
      ob = paise(params[:opening_balance])
      Books.opening_balance(@customer, ob, user: current_user) unless ob.zero?
    end
    redirect_to @customer, notice: "Customer added"
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def update
    attrs = customer_params
    @customer.update(attrs) ? redirect_to(@customer, notice: "Saved") : render(:edit, status: :unprocessable_entity)
  end

  private

  def set_customer = @customer = Customer.find(params[:id])

  def customer_params
    p = params.require(:customer).permit(:name, :owner_name, :phone, :gstin, :market_id, :price_tier, :address)
    p[:credit_limit_paise] = paise(params[:customer][:credit_limit])
    p[:gstin] = p[:gstin].to_s.upcase.strip
    p
  end
end
