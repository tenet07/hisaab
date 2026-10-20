# Turns posted line rows into service items, applying who-may-change-prices rules.
module LineItems
  extend ActiveSupport::Concern

  included do
    helper_method :can_set_rates?
  end

  private

  def line_items(raw, customer: nil)
    rows = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h.values : Array(raw)
    rows = rows.reject { _1["_destroy"] == "1" }
    products = Product.where(id: rows.map { _1["product_id"] }).index_by(&:id)
    rows.filter_map do |r|
      product = products[r["product_id"].to_i]
      next unless product && r["quantity"].present?
      q = r["quantity"].to_s.strip
      raise ArgumentError, "Quantity for #{product.display_name} must be a whole number of pieces" unless q.match?(/\A\d+\z/)
      raise ArgumentError, "Quantity for #{product.display_name} is too large" if q.to_i > 100_000
      next unless q.to_i.positive?
      disc = r["discount_pct"].presence || "0"
      raise ArgumentError, "Discount must be a number between 0 and 100" unless disc.to_s.match?(/\A\d+(\.\d+)?\z/) && disc.to_d <= 100
      tier = product.price_paise_for(customer)
      rate = can_set_rates? && r["rate"].present? ? Money.to_paise(r["rate"]) : tier
      { product: product, quantity: r["quantity"].to_i, rate_paise: rate, discount_pct: r["discount_pct"].to_d }
    end
  end

  def can_set_rates? = Current.user.owner? || Current.user.accounts?

  # Bills on credit that would take a customer past their credit limit need the owner.
  # Returns a message to show when the bill is held, nil when it may go ahead.
  def credit_hold(customer, items, subject: nil)
    return if Current.user.owner? || customer.credit_limit_paise.zero?
    total = Invoicing::Post.estimate(customer: customer, items: items)
    return unless customer.over_credit_limit?(total)
    if subject
      return if Approval.where(subject: subject, kind: "credit_limit", status: "approved", amount_paise: total).exists?
      Approvals.request!(subject, kind: "credit_limit", amount_paise: total,
                                  reason: "#{customer.shop_name}: balance #{Money.format(customer.balance_paise)}, limit #{Money.format(customer.credit_limit_paise)}")
      "#{customer.shop_name} would go over their credit limit — sent to the owner for approval."
    else
      "#{customer.shop_name} would go over their #{Money.format(customer.credit_limit_paise)} credit limit. Take payment now, or save it as an order for the owner to approve."
    end
  end

  # Effective discount against the tier price, for the owner-approval rule.
  def over_discount_limit?(items, customer)
    limit = shop.discount_approval_pct.to_d
    items.any? do |i|
      tier = i[:product].price_paise_for(customer)
      next false if tier.zero?
      net = i[:rate_paise] * (100 - i[:discount_pct]) / 100
      (tier - net) * 100 / tier > limit || net > tier * 2 # big surcharges need a look too
    end
  end

  def line_rows_from(lines, customer = nil)
    stock = StockMovement.where(bucket: "sellable", product_id: lines.map(&:product_id).compact).group(:product_id).sum(:quantity)
    lines.map do |l|
      rate = l.respond_to?(:rate_paise) && l.rate_paise ? l.rate_paise : l.product&.price_paise_for(customer)
      { id: (l.id if l.is_a?(OrderLine)), product_id: l.product_id, label: l.product&.display_name, quantity: l.quantity,
        rate: rate && format("%.2f", rate / 100.0), discount_pct: (l.discount_pct.to_f if l.discount_pct.to_f.positive?),
        gst: l.product&.gst_rate.to_f, stock: stock[l.product_id].to_i,
        source_text: (l.source_text if l.respond_to?(:source_text)), confidence: (l.confidence&.to_f if l.respond_to?(:confidence)) }
    end
  end
end
