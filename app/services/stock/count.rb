module Stock
  # Physical count: system qty is frozen when the sheet is opened; posting writes one
  # count_adjustment movement per difference, each with its reason.
  module Count
    class Error < StandardError; end
    module_function

    def open!(date: Date.current, products: StockCount.products_due(date))
      StockCount.transaction do
        sc = StockCount.create!(count_date: date, counted_by: Current.user)
        products.each { sc.lines.create!(product: _1, system_qty: _1.stock("sellable")) }
        sc
      end
    end

    # Adjustments worth more than the owner's write-off threshold go for approval first.
    def post!(sc, approved: false)
      raise Error, "Already posted" if sc.posted?
      sc.lines.reload
      lines = sc.variance_lines
      missing = lines.select { _1.reason.blank? }
      raise Error, "Give a reason for every difference (#{missing.map { _1.product.sku }.join(', ')})" if missing.any?
      value = lines.sum { _1.variance.abs * _1.product.purchase_paise }
      limit = ShopSetting.current.writeoff_approval_paise
      if !approved && !Current.user&.owner? && limit.positive? && value > limit
        return Approvals.request!(sc, kind: "stock_adjustment", reason: "Count of #{sc.count_date}: #{lines.size} differences",
                                      amount_paise: value)
      end
      StockCount.transaction do
        lines.each do |l|
          StockMovement.create!(product: l.product, bucket: "sellable", quantity: l.variance, reason: "count_adjustment",
                                document: sc, note: l.reason)
        end
        sc.update!(status: "posted")
        sc
      end
    end
  end
end
