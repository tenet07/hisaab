class MarketsController < ApplicationController
  before_action { raise Forbidden unless Current.user.owner? }

  def index = @markets = Market.includes(:salesman).all
  def new = @market = Market.new
  def edit = @market = Market.find(params[:id])

  def create
    @market = Market.new(market_params)
    @market.save ? redirect_to(markets_path, notice: "Market added.") : render(:new, status: :unprocessable_entity)
  end

  def update
    @market = Market.find(params[:id])
    @market.update(market_params) ? redirect_to(markets_path, notice: "Saved.") : render(:edit, status: :unprocessable_entity)
  end

  def destroy
    m = Market.find(params[:id])
    m.destroy ? redirect_to(markets_path, notice: "Removed.") : redirect_to(markets_path, alert: m.errors.full_messages.to_sentence)
  end

  private

  def market_params = params.require(:market).permit(:name, :delivery_weekday, :salesman_id, :position)
end
