class OrdersController < ApplicationController
  include LineItems
  require_permission :orders
  before_action :require_writer!, except: %i[index show]
  before_action :set_order, only: %i[show update confirm convert cancel]

  def index
    @tab = params[:tab].presence || "open"
    scope = Order.includes(:customer, :created_by, lines: :product).recent
    scope = case @tab
            when "open" then scope.open
            when "invoiced" then scope.where(status: "invoiced")
            when "cancelled" then scope.where(status: "cancelled")
            else scope
            end
    scope = scope.where(channel: params[:channel]) if Order::CHANNELS.include?(params[:channel])
    @orders = scope.limit(100)
    @counts = Order.open.group(:channel).count
  end

  def show
    @rows = line_rows_from(@order.lines.includes(:product), @order.customer)
  end

  def new
    @order = Order.new(channel: Current.user.salesman? ? "salesman" : "counter", customer_id: params[:customer_id])
  end

  def create
    customer = Customer.find(params.require(:customer_id))
    if params[:raw_message].present? && params[:lines].blank?
      order = OrderParser.draft!(customer: customer, text: params[:raw_message], channel: params[:channel].presence || "whatsapp")
      return redirect_to(order, notice: "Parsed #{order.lines.size} lines — check and confirm.")
    end
    items = line_items(params[:lines], customer: customer)
    order = Order.create!(customer: customer, channel: params[:channel].presence || "counter", notes: params[:notes],
                          created_by: Current.user, status: "confirmed",
                          lines_attributes: items.map { |i| { product_id: i[:product].id, quantity: i[:quantity], discount_pct: i[:discount_pct],
                                                              rate_paise: (i[:rate_paise] if can_set_rates?) } })
    redirect_to order, notice: "Order #{order.number} saved."
  end

  # AI parse of a pasted WhatsApp message into a draft (from the queue's paste box)
  def parse
    customer = Customer.find(params.require(:customer_id))
    order = OrderParser.draft!(customer: customer, text: params.require(:raw_message), channel: params[:channel].presence || "whatsapp")
    redirect_to order, notice: "Parsed #{order.lines.size} lines — check and confirm with one tap."
  end

  def update
    raise ArgumentError, "This order can't be edited any more" unless @order.editable?
    rows = params[:lines].respond_to?(:to_unsafe_h) ? params[:lines].to_unsafe_h.values : []
    Order.transaction do
      rows.each do |r|
        line = r["id"].present? ? @order.lines.find(r["id"]) : @order.lines.build
        if r["_destroy"] == "1" || (r["product_id"].blank? && r["quantity"].to_i.zero?)
          line.destroy! if line.persisted?
          next
        end
        attrs = { product_id: r["product_id"].presence, quantity: r["quantity"].to_i, discount_pct: r["discount_pct"].to_d }
        attrs[:confidence] = 1 if line.product_id.to_s != r["product_id"].to_s # staff corrected it
        attrs[:rate_paise] = Money.to_paise(r["rate"]) if can_set_rates? && r["rate"].present? && line.product && Money.to_paise(r["rate"]) != line.product.price_paise_for(@order.customer)
        line.update!(attrs)
      end
      @order.update!(notes: params[:notes]) if params.key?(:notes)
    end
    params[:then] == "confirm" ? confirm : redirect_to(@order, notice: "Saved.")
  end

  def confirm
    @order.lines.reload
    @order.confirm!
    redirect_to @order, notice: "Order confirmed. Convert it to an invoice when you're ready to bill."
  end

  def convert
    raise ArgumentError, "Confirm the order first" unless @order.confirmed?
    authorize!(:invoice_post)
    items = @order.lines.includes(:product).map do |l|
      { product: l.product, quantity: l.quantity, rate_paise: l.effective_rate_paise, discount_pct: l.discount_pct }
    end
    if over_discount_limit?(items, @order.customer) && !Current.user.owner? &&
       !Approval.where(subject: @order, kind: "discount", status: "approved").exists?
      Approvals.request!(@order, kind: "discount", reason: "#{@order.number} for #{@order.customer.shop_name}", amount_paise: @order.estimate_paise)
      return redirect_to(@order, alert: "A discount is above #{shop.discount_approval_pct.to_f}% — sent to the owner for approval.")
    end
    inv = Invoicing::Post.call(customer: @order.customer, items: items, order: @order, channel: @order.channel,
                               allow_negative_stock: params[:allow_negative] == "1" && Current.user.owner?)
    WhatsappNotifier.invoice(inv) if params[:whatsapp] != "0"
    redirect_to inv, notice: "Invoice #{inv.number} posted#{' and sent on WhatsApp' if params[:whatsapp] != '0'}."
  end

  def cancel
    raise ArgumentError, "Only open orders can be cancelled" unless @order.editable?
    @order.update!(status: "cancelled", notes: [@order.notes, "Cancelled: #{params[:reason]}"].compact_blank.join("\n"))
    redirect_to orders_path, notice: "Order #{@order.number} cancelled."
  end

  private

  def set_order = @order = Order.find(params[:id])
end
