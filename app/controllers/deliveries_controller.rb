class DeliveriesController < ApplicationController
  before_action :require_office!, only: %i[index assign reschedule summary photo]
  before_action :set_delivery, only: %i[show assign load complete fail reschedule photo]
  before_action :check_access, only: %i[show load complete fail]

  # Office: plan a day's deliveries by market.
  def index
    @date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    @staff = User.active.where(role: "delivery").order(:name)
    @deliveries = Delivery.includes(:assigned_to, invoice: { customer: :market })
                          .where(run_date: @date).or(Delivery.where(status: %w[pending failed]).where("run_date < ?", @date))
                          .where.not(status: "cancelled")
                          .sort_by { |d| [d.invoice.customer.market.name, d.invoice.customer.name] }
    @by_market = @deliveries.group_by { |d| d.invoice.customer.market }
  end

  # Delivery staff: today's stops (plus anything overdue assigned to them).
  def run
    @date = Date.current
    scope = Delivery.includes(invoice: { customer: :market }, items: { invoice_line: :product })
                    .where("run_date <= ?", @date).where(status: Delivery::OPEN)
    scope = scope.where(assigned_to: current_user) if current_user.delivery?
    @open = scope.sort_by { |d| [d.invoice.customer.market.name, d.invoice.customer.name] }
    done_scope = Delivery.includes(invoice: :customer).where(delivered_at: @date.all_day).or(
      Delivery.includes(invoice: :customer).where(status: "failed", updated_at: @date.all_day))
    done_scope = done_scope.where(assigned_to: current_user) if current_user.delivery?
    @done = done_scope.order(updated_at: :desc)
    @cash = Payment.where(delivery_id: @done.map(&:id), mode: "cash").sum(:amount_paise)
  end

  def show
    @items = @delivery.items.includes(invoice_line: :product)
    @customer = @delivery.invoice.customer
  end

  def assign
    to = params[:assigned_to_id].present? ? User.find(params[:assigned_to_id]) : nil
    Books.assign_delivery(@delivery, to: to, run_date: Date.parse(params[:run_date]), user: current_user)
    redirect_to deliveries_path(date: params[:back_date] || @delivery.run_date), notice: "#{@delivery.invoice.number} planned"
  end

  def load
    Books.load_delivery(@delivery, loaded: (params[:loaded]&.to_unsafe_h || {}), user: current_user)
    redirect_to @delivery, notice: "Loaded. Now deliver and collect the customer's code."
  end

  def complete
    photo = params[:photo].presence && { data: params[:photo].read, type: params[:photo].content_type }
    Books.complete_delivery(@delivery, delivered: (params[:delivered]&.to_unsafe_h || {}),
                            reasons: (params[:reasons]&.to_unsafe_h || {}),
                            damaged: (params[:damaged]&.to_unsafe_h || {}), otp: params[:otp], photo: photo,
                            cash_paise: paise(params[:cash]), cash_mode: params[:cash_mode].presence || "cash",
                            user: current_user)
    @delivery.reload
    msg = @delivery.status == "delivered" ? "Delivered" : "Partly delivered; credit note made for the rest"
    redirect_to run_deliveries_path, notice: "#{@delivery.invoice.customer.name}: #{msg}"
  end

  def fail
    Books.fail_delivery(@delivery, reason: params[:reason], user: current_user)
    redirect_to run_deliveries_path, notice: "Marked not delivered. Bring the goods back; the office will reschedule."
  end

  def reschedule
    Books.reschedule_delivery(@delivery, run_date: Date.parse(params[:run_date]), user: current_user)
    redirect_to deliveries_path(date: params[:run_date]), notice: "Rescheduled"
  end

  # Office: end-of-day check per delivery person.
  def summary
    @date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    day = Delivery.includes(:assigned_to, :payments, :credit_notes, invoice: :customer)
                  .where(run_date: @date).where.not(status: "cancelled")
    @rows = day.group_by(&:assigned_to).map do |person, ds|
      { person: person, total: ds.size,
        delivered: ds.count { _1.status == "delivered" }, partly: ds.count { _1.status == "partly_delivered" },
        failed: ds.select { _1.status == "failed" }, open: ds.select(&:open?),
        cash: ds.flat_map(&:payments).select { _1.mode == "cash" }.sum(&:amount_paise),
        upi: ds.flat_map(&:payments).reject { _1.mode == "cash" }.sum(&:amount_paise),
        credits: ds.flat_map(&:credit_notes) }
    end
  end

  def photo
    return head(:not_found) unless @delivery.photo_data
    send_data @delivery.photo_data, type: @delivery.photo_type, disposition: "inline"
  end

  private

  def set_delivery = @delivery = Delivery.find(params[:id])

  def check_access
    return if current_user.office?
    return if current_user.delivery? && [nil, current_user.id].include?(@delivery.assigned_to_id)
    redirect_to run_deliveries_path, alert: "This delivery is assigned to someone else"
  end
end
