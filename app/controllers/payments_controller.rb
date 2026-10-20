class PaymentsController < ApplicationController
  require_permission :payments
  before_action :require_writer!, except: %i[index show]

  def index
    scope = Payment.includes(:customer, :collected_by).recent
    scope = scope.where(collected_by: Current.user, received_on: 7.days.ago.to_date..) unless can?(:ledgers)
    scope = scope.where(received_on: date_param(params[:from])..) if params[:from].present?
    scope = scope.where(received_on: ..date_param(params[:to])) if params[:to].present?
    scope = scope.where(mode: params[:mode]) if params[:mode].present?
    scope = scope.where(collected_by_id: params[:user_id]) if params[:user_id].present?
    @payments = scope.limit(300)
    @by_mode = @payments.reject(&:bounced?).group_by(&:mode).transform_values { _1.sum(&:amount_paise) }
  end

  def show
    @payment = Payment.find(params[:id])
    raise Forbidden unless can?(:ledgers) || @payment.collected_by_id == Current.user.id
  end

  def new
    @customer = Customer.find_by(id: params[:customer_id])
  end

  def create
    customer = Customer.find(params.require(:customer_id))
    pay = Payments::Record.call(customer: customer, amount_paise: Money.to_paise(params[:amount]), mode: params[:mode],
                                reference: params[:reference], notes: params[:notes], client_uuid: params[:client_uuid],
                                received_on: can?(:ledgers) ? date_param(params[:received_on]) : Date.current)
    WhatsappNotifier.receipt(pay) if params[:whatsapp] == "1"
    redirect_to pay, notice: "#{Money.format(pay.amount_paise)} recorded#{' — receipt sent on WhatsApp' if params[:whatsapp] == '1'}."
  end

  def bounce
    authorize!(:payments_bounce)
    pay = Payment.find(params[:id])
    Payments::Bounce.call(pay, reason: params[:reason].presence || "Cheque returned")
    redirect_to pay, notice: "Marked bounced. The amount is back on #{pay.customer.shop_name}'s account."
  end

  def send_receipt
    pay = Payment.find(params[:id])
    raise Forbidden unless can?(:ledgers) || pay.collected_by_id == Current.user.id
    WhatsappNotifier.receipt(pay)
    redirect_to pay, notice: "Receipt sent."
  end
end
