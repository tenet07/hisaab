module Stock
  # Reorder level from sales history: average daily sales over the window × (lead time + safety days).
  module Reorder
    module_function

    def suggestions(window_days: 90, lead_days: 7, safety_days: 7)
      from = Date.current - window_days
      sold = StockMovement.where(reason: "sale", created_at: from.beginning_of_day..).group(:product_id).sum(:quantity)
      reversed = StockMovement.where(reason: "sale_reversal", created_at: from.beginning_of_day..).group(:product_id).sum(:quantity)
      Product.active.includes(:brand).with_stock.filter_map do |p|
        units = -sold[p.id].to_i - reversed[p.id].to_i
        next if units <= 0 && p.reorder_level.zero?
        per_day = units.to_f / window_days
        level = (per_day * (lead_days + safety_days)).ceil
        { product: p, sold: units, per_day: per_day.round(2), suggested: level, current: p.reorder_level,
          stock: p.stock_qty.to_i, order_qty: [level * 2 - p.stock_qty.to_i, 0].max }
      end.sort_by { -_1[:sold] }
    end

    def apply!(rows)
      Product.transaction { rows.each { |r| r[:product].update!(reorder_level: r[:suggested]) } }
    end
  end
end
