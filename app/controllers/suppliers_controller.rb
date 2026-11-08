class SuppliersController < ApplicationController
  before_action :require_office!
  before_action :set_supplier, only: %i[show edit update]

  def index
    @suppliers = Supplier.order(:name)
    @payables = SupplierEntry.group(:supplier_id).sum("credit_paise - debit_paise")
  end

  def show
    @entries = @supplier.entries.includes(:user).order(:date, :id)
    @unpaid = @supplier.unpaid_bills
    @claims = @supplier.claims.includes(:credits, lines: :product).order(created_at: :desc)
  end

  def new = @supplier = Supplier.new
  def edit; end

  def create
    @supplier = Supplier.new(supplier_params)
    Supplier.transaction do
      @supplier.save!
      ob = paise(params[:opening_balance])
      Books.supplier_opening(@supplier, ob, user: current_user) unless ob.zero?
    end
    redirect_to @supplier, notice: "Supplier added"
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def update
    @supplier.update(supplier_params) ? redirect_to(@supplier, notice: "Saved") : render(:edit, status: :unprocessable_entity)
  end

  private

  def set_supplier = @supplier = Supplier.find(params[:id])
  def supplier_params = params.require(:supplier).permit(:name, :gstin, :phone, :brands, :credit_days, :address)
end
