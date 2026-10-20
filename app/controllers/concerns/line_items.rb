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
      next unless product && r["quantity"].to_i.positive?
      tier = product.price_paise_for(customer)
      rate = can_set_rates? && r["rate"].present? ? Money.to_paise(r["rate"]) : tier
      { product: product, quantity: r["quantity"].to_i, rate_paise: rate, discount_pct: r["discount_pct"].to_d }
    end
  end

  def can_set_rates? = Current.user.owner? || Current.user.accounts?

  # Effective discount against the tier price, for the owner-approval rule.
  def over_discount_limit?(items, customer)
    limit = shop.discount_approval_pct.to_d
    items.any? do |i|
      tier = i[:product].price_paise_for(customer)
      next false if tier.zero?
      net = i[:rate_paise] * (100 - i[:discount_pct]) / 100
      (tier - net) * 100 / tier > limit
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
