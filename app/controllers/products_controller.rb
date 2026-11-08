class ProductsController < ApplicationController
  before_action :require_office!, except: %i[index show]
  before_action :set_product, only: %i[show edit update adjust]

  def index
    @products = Product.order(:brand, :name)
    @products = @products.where("name LIKE :q OR sku LIKE :q OR brand LIKE :q", q: "%#{params[:q]}%") if params[:q].present?
  end
  def show = @movements = @product.stock_movements.includes(:user).order(created_at: :desc).limit(50)
  def new = @product = Product.new(gst_bp: 1800)
  def edit; end

  def create
    @product = Product.new(product_params)
    if @product.save
      Books.opening_stock(@product, params[:opening_qty].to_i, user: current_user) if params[:opening_qty].to_i.positive?
      redirect_to @product, notice: "Product added"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @product.update(product_params) ? redirect_to(@product, notice: "Saved") : render(:edit, status: :unprocessable_entity)
  end

  def adjust
    diff = Books.count_adjustment(@product, counted: params[:counted].to_i, reason: params[:reason], user: current_user)
    redirect_to @product, notice: diff.zero? ? "Count matches, nothing posted" : "Adjusted by #{diff}"
  end

  private

  def set_product = @product = Product.find(params[:id])

  def product_params
    p = params.require(:product).permit(:sku, :name, :brand, :hsn, :gst_bp, :price_includes_tax,
                                        :warranty_months, :reorder_level)
    p[:retail_price_paise] = paise(params[:product][:retail_price])
    p[:wholesale_price_paise] = paise(params[:product][:wholesale_price])
    p
  end
end
