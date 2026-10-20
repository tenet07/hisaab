module M
  class OrdersController < BaseController
    before_action { authorize!(:orders) }
    before_action :own_customer!
    include LineItems

    def new
      @customer = Customer.find(params[:customer_id])
    end

    def create
      order = Mobile::Capture.order(customer: Customer.find(params[:customer_id]), lines: params[:lines], notes: params[:notes],
                                    client_uuid: params[:client_uuid])
      redirect_to m_customer_path(order.customer), notice: "Order #{order.number} sent to the office."
    end
  end
end
