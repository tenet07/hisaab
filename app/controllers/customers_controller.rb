require "csv"

class CustomersController < ApplicationController
  require_permission :customers
  before_action :set_customer, only: %i[show edit update statement send_statement]
  before_action(only: %i[new create edit update import_form import]) { authorize!(:customers_edit) }

  def index
    scope = Customer.with_balance.includes(:market).order(:shop_name)
    scope = scope.search(params[:q])
    scope = scope.where(market_id: params[:market_id]) if params[:market_id].present?
    scope = scope.where(active: params[:inactive] != "1")
    @customers = scope.to_a
    if can?(:ledgers)
      @customers.sort_by! { -_1.balance_paise } if params[:sort] == "balance"
      @customers.select! { _1.balance_paise.positive? } if params[:owing] == "1"
    end
  end

  def show
    if params[:dues]
      return head(:no_content) unless can?(:ledgers)
      return render(partial: "payments/dues", locals: { customer: @customer })
    end
    tabs = can?(:ledgers) ? %w[ledger bills replacements profile] : %w[replacements profile]
    @tab = params[:tab].presence_in(tabs) || tabs.first
    @from = params[:from].present? ? date_param(params[:from]) : Date.current - 90
    @to = params[:to].present? ? date_param(params[:to]) : Date.current
    if can?(:ledgers)
      @opening = @customer.balance_on(@from - 1)
      @entries = @customer.ledger_entries.where(entry_date: @from..@to).chronological.includes(:document, :user)
    end
    if can?(:ledgers)
      @open = @customer.open_items
      @ageing = @customer.ageing
    end
  end

  def new = @customer = Customer.new(market_id: params[:market_id], credit_limit_paise: 0)
  def edit; end

  def create
    @customer = Customer.new(customer_params)
    if @customer.save
      OpeningBalance.post!(@customer, Money.to_paise(params[:opening_balance]))
      redirect_to @customer, notice: "Customer #{@customer.code} added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @customer.update(customer_params)
      redirect_to @customer, notice: "Saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def statement
    authorize!(:ledgers)
    from = date_param(params[:from], Date.current.beginning_of_month)
    to = date_param(params[:to])
    send_data StatementPdf.new(@customer, from: from, to: to).render, filename: "statement-#{@customer.code}-#{from}.pdf",
              type: "application/pdf", disposition: "inline"
  end

  def send_statement
    require_writer!
    authorize!(:ledgers)
    WhatsappNotifier.statement(@customer, from: Date.current.beginning_of_month, to: Date.current)
    redirect_back fallback_location: @customer, notice: "Statement sent on WhatsApp."
  end

  def import_form; end

  # CSV columns: shop_name, owner_name, phone, gstin, market, address, credit_limit, price_tier, opening_balance, marketing_opt_in
  def import
    file = params.require(:file)
    created = 0
    errors = []
    Customer.transaction do
      CSV.foreach(file.path, headers: true, header_converters: ->(h) { h.to_s.strip.downcase.tr(" ", "_") }).with_index(2) do |row, line|
        market = row["market"].present? ? Market.find_or_create_by!(name: row["market"].strip) : nil
        c = Customer.new(shop_name: row["shop_name"], owner_name: row["owner_name"], phone: row["phone"], gstin: row["gstin"],
                         market: market, address: row["address"], credit_limit: row["credit_limit"].presence || 0,
                         price_tier: row["price_tier"].presence || "wholesale", marketing_opt_in: %w[1 yes y true].include?(row["marketing_opt_in"].to_s.downcase))
        unless c.save
          errors << "Row #{line}: #{c.errors.full_messages.to_sentence}"
          next
        end
        created += 1
        OpeningBalance.post!(c, Money.to_paise(row["opening_balance"]), narration: "Opening balance (import)")
      end
      raise ActiveRecord::Rollback if errors.any? && params[:all_or_nothing] == "1"
    end
    flash[errors.any? ? :alert : :notice] = "Imported #{created} customers. #{errors.first(5).join(' · ')}"
    redirect_to customers_path
  end

  private

  def set_customer = @customer = Customer.find(params[:id])

  def customer_params
    p = params.require(:customer).permit(:shop_name, :owner_name, :phone, :gstin, :state_code, :address, :market_id, :credit_limit,
                                         :price_tier, :marketing_opt_in, :active, :code)
    p.delete(:credit_limit) unless Current.user.owner? || Current.user.accounts?
    p
  end
end
