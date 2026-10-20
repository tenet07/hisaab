module M
  # The phone app for salesmen and delivery staff.
  class BaseController < ApplicationController
    layout "mobile"
    before_action :require_mobile

    private

    def require_mobile = authorize!(:mobile)

    # Salesmen work their own markets' shops
    def own_customer!
      id = params[:customer_id] || (params[:id] if controller_name == "customers")
      return if id.blank? || !Current.user.salesman?
      raise Forbidden unless Customer.where(id: id, market_id: Current.user.markets.select(:id)).exists?
    end
  end
end
