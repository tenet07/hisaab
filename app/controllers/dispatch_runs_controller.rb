# Dispatch planned by market route. Only posted invoices can go on a run — no dispatch without a bill.
class DispatchRunsController < ApplicationController
  require_permission :dispatch
  before_action :require_writer!, except: %i[index show]
  before_action :set_run, only: %i[show update add remove start finish]

  def index
    @date = date_param(params[:date])
    @runs = DispatchRun.for_date(@date).includes(:market, :delivery_person, deliveries: { invoice: :customer }).index_by(&:market_id)
    @pending = Invoice.undispatched.where(invoice_date: (@date - 14)..@date).includes(customer: :market).group_by { _1.customer.market_id }
    @markets = Market.all.to_a
  end

  def create
    run = DispatchRun.find_or_create_by!(market_id: params[:market_id], run_date: date_param(params[:date])) do |r|
      r.delivery_person = User.active.with_role("delivery").first
    end
    if params[:auto] == "1"
      Invoice.undispatched.joins(:customer).where(customers: { market_id: run.market_id }).where(invoice_date: (run.run_date - 14)..run.run_date)
             .order(:invoice_date).each_with_index { |inv, i| run.deliveries.create!(invoice: inv, position: run.deliveries.size + i) }
    end
    redirect_to run
  end

  def show
    @available = Invoice.undispatched.joins(:customer).where(customers: { market_id: @run.market_id }).includes(:customer).order(:invoice_date)
  end

  def update
    @run.update!(params.require(:dispatch_run).permit(:delivery_person_id, :vehicle))
    if params[:order].present?
      params[:order].split(",").each_with_index { |id, i| @run.deliveries.find(id).update_columns(position: i) }
    end
    redirect_to @run, notice: "Saved."
  end

  def add
    Array(params[:invoice_ids]).each do |id|
      inv = Invoice.posted.find(id)
      raise ArgumentError, "#{inv.number} needs an e-way bill number before dispatch" if inv.eway_required && inv.eway_bill_no.blank?
      @run.deliveries.create!(invoice: inv, position: @run.deliveries.size)
    end
    redirect_to @run
  end

  def remove
    d = @run.deliveries.find(params[:delivery_id])
    raise ArgumentError, "Delivered drops can't be removed" if d.done?
    d.destroy!
    redirect_to @run
  end

  # Out for delivery: each customer gets their drop OTP on WhatsApp.
  def start
    @run.update!(status: "out")
    @run.deliveries.reject(&:done?).each do |d|
      WhatsappNotifier.text(d.customer, "Your order #{d.invoice.number} (#{Money.format(d.invoice.total_paise)}) is out for delivery today. " \
                                        "Share OTP #{d.otp_code} with our delivery person when it arrives.")
    end
    redirect_to @run, notice: "Run started. OTPs sent to #{@run.deliveries.count { !_1.done? }} customers."
  end

  def finish
    @run.update!(status: "done")
    redirect_to dispatch_runs_path(date: @run.run_date), notice: "Run closed."
  end

  private

  def set_run = @run = DispatchRun.find(params[:id])
end
