module M
  class HomeController < BaseController
    allow_unauthenticated_access only: :offline
    skip_before_action :require_mobile, only: :offline

    def show
      return redirect_to(m_route_path) if Current.user.delivery?
      markets = Current.user.owner? ? Market.all.to_a : Current.user.markets.to_a
      @today = markets.select(&:today?)
      @markets = (@today + (markets - @today))
      @market = Market.find_by(id: params[:market_id]) || @today.first || @markets.first
      @customers = @market ? @market.customers.active.with_balance.order(:shop_name).to_a : []
      @collected = Payment.cleared.where(collected_by: Current.user, received_on: Date.current).sum(:amount_paise)
      @orders = Order.where(created_by: Current.user, created_at: Date.current.all_day).count
    end

    def offline
      render layout: false
    end
  end
end
