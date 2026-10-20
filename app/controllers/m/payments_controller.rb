module M
  class PaymentsController < BaseController
    def new = @customer = Customer.find(params[:customer_id])

    def create
      pay = Mobile::Capture.payment(customer: Customer.find(params[:customer_id]), amount: params[:amount], mode: params[:mode],
                                    reference: params[:reference], client_uuid: params[:client_uuid])
      redirect_to m_customer_path(pay.customer), notice: "#{Money.format(pay.amount_paise)} recorded. Receipt sent on WhatsApp."
    end
  end
end
