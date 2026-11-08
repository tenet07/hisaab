class PaymentsController < ApplicationController
  before_action { @customer = Customer.find(params[:customer_id]) }
  def new; end
  def create
    pay = Books.record_payment(customer: @customer, amount_paise: paise(params[:amount]), mode: params[:mode],
                               ref: params[:ref], note: params[:note], user: current_user)
    flash[:whatsapp] = helpers.wa_link(@customer, helpers.receipt_message(pay))
    redirect_to(current_user.field? ? visit_customer_path(@customer) : customer_path(@customer),
                notice: "#{Shop::Money.format(pay.amount_paise)} recorded")
  end
end
