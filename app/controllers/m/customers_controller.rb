module M
  # The visit screen: amount due, oldest unpaid bill, last 3 orders, open replacements, and the
  # three things a salesman does at a shop. No prices or balances can be changed from here.
  class CustomersController < BaseController
    def index
      scope = Customer.active.includes(:market).order(:shop_name)
      scope = scope.where(market: Current.user.markets) if Current.user.salesman? && params[:all] != "1"
      @customers = scope.search(params[:q]).limit(100)
    end

    def show
      @customer = Customer.find(params[:id])
      @oldest = @customer.oldest_unpaid
      @orders = @customer.orders.includes(lines: :product).recent.limit(3)
      @replacements = @customer.replacements.open_claims.includes(:product).recent
    end
  end
end
