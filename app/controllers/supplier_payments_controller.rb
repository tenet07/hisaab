class SupplierPaymentsController < ApplicationController
  before_action :require_owner_or_accounts!
  before_action { @supplier = Supplier.find(params[:supplier_id]) }
  def new; end
  def create
    pay = Books.pay_supplier(supplier: @supplier, amount_paise: paise(params[:amount]), mode: params[:mode],
                             ref: params[:ref], user: current_user, date: Date.parse(params[:date]))
    redirect_to @supplier, notice: "Paid #{Shop::Money.format(pay.amount_paise)} to #{@supplier.name}"
  end
end
