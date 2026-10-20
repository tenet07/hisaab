# Rotating physical counts: each month a slice of the range is counted; differences post with a reason.
class StockCountsController < ApplicationController
  require_permission :counts
  before_action :require_writer!, except: %i[index show]

  def index
    @counts = StockCount.includes(:counted_by, :lines).order(count_date: :desc)
    @due = StockCount.products_due.count
  end

  def new
    @due = StockCount.products_due.includes(:brand)
  end

  def create
    products = params[:scope] == "all" ? Product.active : StockCount.products_due
    sc = Stock::Count.open!(products: products)
    redirect_to sc, notice: "Count sheet opened with #{sc.lines.size} products. System quantities are frozen as of now."
  end

  def show
    @count = StockCount.find(params[:id])
    @lines = @count.lines.includes(product: :brand).order("products.brand_id, products.name").references(:products)
  end

  def update
    sc = StockCount.find(params[:id])
    raise ArgumentError, "Already posted" if sc.posted?
    (params[:lines]&.to_unsafe_h || {}).each do |id, r|
      sc.lines.find(id).update!(counted_qty: r["counted_qty"].presence&.to_i, reason: r["reason"].presence)
    end
    redirect_to sc, notice: "Saved."
  end

  def post_count
    result = Stock::Count.post!(StockCount.find(params[:id]))
    if result.is_a?(Approval)
      redirect_to stock_count_path(params[:id]), notice: "Adjustments are above the owner's limit — sent for approval."
    else
      redirect_to result, notice: "Count posted: #{result.variance_lines.size} adjustments written to the stock ledger."
    end
  end
end
