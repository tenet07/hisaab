require "csv"

class ProductsController < ApplicationController
  require_permission :products
  before_action(except: %i[index show]) { authorize!(:products_edit) }
  before_action :set_product, only: %i[show edit update]

  def index
    scope = Product.joins(:brand).includes(:brand).with_stock.search(params[:q]).order("brands.name, products.name")
    scope = scope.where(brand_id: params[:brand_id]) if params[:brand_id].present?
    scope = scope.where(active: params[:inactive] != "1")
    @products = scope.to_a
  end

  def show
    @buckets = @product.stock_by_bucket
    @movements = @product.stock_movements.includes(:document, :user).recent.limit(100)
    @sold_90 = -@product.stock_movements.where(reason: "sale", created_at: 90.days.ago..).sum(:quantity)
  end

  def new = @product = Product.new(gst_rate: 18, brand_id: params[:brand_id])
  def edit; end

  def create
    @product = Product.new(product_params)
    if @product.save
      Stock::Opening.post!(@product, params[:opening_stock]) if params[:opening_stock].present?
      redirect_to @product, notice: "Product added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @product.update(product_params) ? redirect_to(@product, notice: "Saved.") : render(:edit, status: :unprocessable_entity)
  end

  def reorder
    @window = (params[:window] || 90).to_i
    @rows = Stock::Reorder.suggestions(window_days: @window, lead_days: (params[:lead] || 7).to_i, safety_days: (params[:safety] || 7).to_i)
  end

  def apply_reorder
    ids = Array(params[:product_ids]).map(&:to_i)
    rows = Stock::Reorder.suggestions(window_days: (params[:window] || 90).to_i).select { ids.include?(_1[:product].id) }
    Stock::Reorder.apply!(rows)
    redirect_to reorder_products_path, notice: "Reorder levels updated for #{rows.size} products."
  end

  def import_form; end

  # CSV: brand, sku, name, model, wattage, hsn, gst_rate, mrp, wholesale, retail, purchase, reorder_level, warranty_months, aliases, opening_stock
  def import
    created = updated = 0
    errors = []
    Product.transaction do
      CSV.foreach(params.require(:file).path, headers: true, header_converters: ->(h) { h.to_s.strip.downcase.tr(" ", "_") }).with_index(2) do |row, line|
        brand = Brand.find_or_create_by!(name: row["brand"].to_s.strip.presence || "Unbranded")
        p = Product.find_or_initialize_by(sku: row["sku"].to_s.strip.upcase)
        p.assign_attributes(brand: brand, name: row["name"], model: row["model"], wattage: row["wattage"], hsn: row["hsn"],
                            gst_rate: row["gst_rate"].presence || 18, mrp: row["mrp"] || 0, wholesale: row["wholesale"] || 0,
                            retail: row["retail"] || 0, purchase: row["purchase"] || 0, reorder_level: row["reorder_level"].to_i,
                            warranty_months: row["warranty_months"].presence, aliases: row["aliases"])
        was_new = p.new_record?
        if p.save
          was_new ? created += 1 : updated += 1
          Stock::Opening.post!(p, row["opening_stock"], note: "Opening stock (import)") if was_new && row["opening_stock"].to_i != 0
        else
          errors << "Row #{line}: #{p.errors.full_messages.to_sentence}"
        end
      end
    end
    flash[errors.any? ? :alert : :notice] = "#{created} added, #{updated} updated. #{errors.first(5).join(' · ')}"
    redirect_to products_path
  end

  private

  def set_product = @product = Product.find(params[:id])

  def product_params
    params.require(:product).permit(:brand_id, :sku, :name, :model, :wattage, :hsn, :gst_rate, :mrp, :retail, :wholesale, :purchase,
                                    :reorder_level, :warranty_months, :unit, :aliases, :active)
  end
end
