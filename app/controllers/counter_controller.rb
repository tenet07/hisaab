# Quick billing at the counter: walk-in (B2C, MRP-style tax-inclusive) or a known dealer, with
# optional pay-now so a cash/UPI sale is billed and settled in one go.
class CounterController < ApplicationController
  include LineItems
  require_permission :invoice_post
  before_action :require_writer!

  def new
    @last = Invoice.find_by(id: params[:last])
    sold = StockMovement.where(reason: "sale", created_at: 30.days.ago..).group(:product_id).sum(:quantity)
    @top = Product.active.includes(:brand).where(id: sold.sort_by(&:last).first(12).map(&:first)).to_a
    @top = Product.active.includes(:brand).limit(12).to_a if @top.empty?
  end

  def create
    customer = params[:customer_id].present? ? Customer.find(params[:customer_id]) : walk_in
    items = line_items(params[:lines], customer: customer)
    if over_discount_limit?(items, customer) && !Current.user.owner?
      raise ArgumentError, "Discount above #{shop.discount_approval_pct.to_f}% needs the owner. Ask them to bill it."
    end
    on_credit = params[:pay_mode].blank? || params[:pay_mode] == "credit"
    raise ArgumentError, "A walk-in sale must be paid now (cash or UPI). Pick a customer to bill on credit." if on_credit && customer == walk_in
    if on_credit && (msg = credit_hold(customer, items))
      raise ArgumentError, msg
    end
    inv = nil
    Invoice.transaction do
      inv = Invoicing::Post.call(customer: customer, items: items, channel: "counter",
                                 bill_to_name: (params[:bill_to_name].presence if customer == walk_in))
      unless on_credit
        # the money is for this bill, so it settles this bill — not an older one
        Payments::Record.call(customer: customer, amount_paise: inv.total_paise, mode: params[:pay_mode], reference: params[:pay_ref], apply_to: inv)
      end
    end
    WhatsappNotifier.invoice(inv) if params[:whatsapp] == "1" && customer != walk_in
    redirect_to counter_path(last: inv.id), notice: "#{inv.number} · #{Money.format(inv.total_paise)}#{' · paid' unless inv.reload.unpaid?}"
  end

  private

  def walk_in
    @walk_in ||= Customer.find_by(code: "CASH") ||
                 Customer.create!(code: "CASH", shop_name: "Cash customer (counter)", phone: "9100000000", price_tier: "retail")
  end
  helper_method :walk_in
end
