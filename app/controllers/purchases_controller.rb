class PurchasesController < ApplicationController
  include LineItems
  require_permission :purchases
  before_action :require_writer!, only: %i[new create]

  def index
    @purchases = Purchase.includes(:supplier).recent.limit(200)
    @suppliers = Supplier.includes(:brand).order(:name)
  end

  def show = @purchase = Purchase.find(params[:id])
  def new = @purchase = Purchase.new(bill_date: Date.current, supplier_id: params[:supplier_id])

  def create
    supplier = Supplier.find(params.require(:supplier_id))
    rows = params[:lines].respond_to?(:to_unsafe_h) ? params[:lines].to_unsafe_h.values : []
    products = Product.where(id: rows.map { _1["product_id"] }).index_by(&:id)
    items = rows.filter_map do |r|
      p = products[r["product_id"].to_i]
      { product: p, quantity: r["quantity"].to_i, rate_paise: Money.to_paise(r["rate"]).to_i } if p
    end
    purchase = Stock::PurchaseEntry.call(supplier: supplier, bill_no: params[:bill_no], bill_date: date_param(params[:bill_date]), items: items)
    redirect_to purchase, notice: "Purchase entered: #{purchase.lines.sum(:quantity)} pieces into sellable stock."
  end
end
