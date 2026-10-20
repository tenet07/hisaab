# Stock by bucket, straight from the movement ledger.
class StockController < ApplicationController
  before_action { raise Forbidden unless can?(:stock) || can?(:stock_lookup) }

  def index
    balances = StockMovement.balances
    scope = Product.active.joins(:brand).includes(:brand).search(params[:q]).order("brands.name, products.name")
    scope = scope.where(brand_id: params[:brand_id]) if params[:brand_id].present?
    @rows = scope.map { |p| [p, StockMovement::BUCKETS.index_with { balances[[p.id, _1]].to_i }] }
    @rows.select! { |p, b| b["sellable"] <= p.reorder_level } if params[:low] == "1"
    @totals = StockMovement::BUCKETS.index_with { |b| @rows.sum { _2[b] } }
    @value = @rows.sum { |p, b| b["sellable"] * p.purchase_paise } if can?(:margins)
  end

  def movements
    authorize!(:stock)
    scope = StockMovement.includes(:product, :user, :document).recent
    scope = scope.where(reason: params[:reason]) if params[:reason].present?
    scope = scope.where(bucket: params[:bucket]) if params[:bucket].present?
    scope = scope.where(created_at: date_param(params[:from]).beginning_of_day..) if params[:from].present?
    @movements = scope.limit(300)
  end
end
