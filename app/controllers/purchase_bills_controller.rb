class PurchaseBillsController < ApplicationController
  before_action :require_office!

  def index
    @bills = PurchaseBill.includes(:supplier).order(date: :desc, id: :desc).limit(200)
  end

  def new
    @supplier = Supplier.find_by(id: params[:supplier_id])
    @suppliers = Supplier.order(:name)
    @products = Product.order(:brand, :name)
    @products = @products.select { |p| @supplier.brand_list.map(&:downcase).include?(p.brand.downcase) } if @supplier&.brand_list&.any?
  end

  def create
    supplier = Supplier.find(params[:supplier_id])
    rows = params[:items].respond_to?(:values) ? params[:items].values : []
    items = rows.filter_map do |i|
      next if i[:product_id].blank?
      { product: Product.find(i[:product_id]), qty: i[:qty].to_i, rate_paise: paise(i[:rate]), discount_paise: paise(i[:discount]) }
    end
    bill = Books.create_purchase(supplier: supplier, number: params[:number], date: Date.parse(params[:date]),
                                 items: items, user: current_user, printed_total_paise: paise(params[:printed_total]))
    redirect_to purchase_bill_path(bill), notice: "Purchase #{bill.number} entered; stock added"
  end

  def show = @bill = PurchaseBill.includes(:supplier, lines: :product).find(params[:id])
end
