class SupplierPaymentsController < ApplicationController
  require_permission :purchases
  before_action :require_writer!

  def create
    supplier = Supplier.find(params[:supplier_id])
    SupplierPayment.transaction do
      sp = supplier.supplier_payments.create!(amount_paise: Money.to_paise(params[:amount]), mode: params[:mode], reference: params[:reference],
                                              paid_on: date_param(params[:paid_on]), created_by: Current.user)
      LedgerEntry.create!(party: supplier, entry_date: sp.paid_on, debit_paise: sp.amount_paise, entry_type: "supplier_payment",
                          narration: "Paid #{sp.mode} #{sp.reference}".strip)
    end
    redirect_to supplier, notice: "Payment to #{supplier.name} recorded."
  end
end
