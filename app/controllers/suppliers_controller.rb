class SuppliersController < ApplicationController
  require_permission :purchases
  before_action :require_writer!, except: %i[index show]
  before_action :set_supplier, only: %i[show edit update]

  def index = redirect_to(purchases_path)

  def show
    @entries = @supplier.ledger_entries.chronological.includes(:document)
  end

  def new = @supplier = Supplier.new
  def edit; end

  def create
    @supplier = Supplier.new(supplier_params)
    @supplier.save ? redirect_to(@supplier, notice: "Supplier added.") : render(:new, status: :unprocessable_entity)
  end

  def update
    @supplier.update(supplier_params) ? redirect_to(@supplier, notice: "Saved.") : render(:edit, status: :unprocessable_entity)
  end

  private

  def set_supplier = @supplier = Supplier.find(params[:id])
  def supplier_params = params.require(:supplier).permit(:name, :brand_id, :gstin, :state_code, :phone, :address)
end
