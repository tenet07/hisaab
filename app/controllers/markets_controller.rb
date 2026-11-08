class MarketsController < ApplicationController
  before_action :require_office!, except: :index
  def index = @markets = Market.includes(:salesman, :delivery_person, :customers).order(:name)
  def new = @market = Market.new
  def create
    @market = Market.new(params.require(:market).permit(:name, :delivery_day, :salesman_id, :delivery_person_id))
    @market.save ? redirect_to(markets_path, notice: "Market added") : render(:new, status: :unprocessable_entity)
  end
end
