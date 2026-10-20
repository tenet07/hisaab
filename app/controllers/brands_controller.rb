class BrandsController < ApplicationController
  before_action { raise Forbidden unless Current.user.owner? || can?(:products_edit) }

  def index = @brands = Brand.all
  def new = @brand = Brand.new
  def edit = @brand = Brand.find(params[:id])

  def create
    @brand = Brand.new(brand_params)
    @brand.save ? redirect_to(brands_path, notice: "Brand added.") : render(:new, status: :unprocessable_entity)
  end

  def update
    @brand = Brand.find(params[:id])
    @brand.update(brand_params) ? redirect_to(brands_path, notice: "Saved.") : render(:edit, status: :unprocessable_entity)
  end

  def destroy
    b = Brand.find(params[:id])
    b.destroy ? redirect_to(brands_path, notice: "Removed.") : redirect_to(brands_path, alert: b.errors.full_messages.to_sentence)
  end

  private

  def brand_params = params.require(:brand).permit(:name, :warranty_months, :claim_contact)
end
