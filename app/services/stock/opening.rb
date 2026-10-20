module Stock
  module Opening
    module_function

    def post!(product, quantity, note: "Opening stock")
      return if quantity.to_i.zero?
      StockMovement.create!(product: product, bucket: "sellable", quantity: quantity.to_i, reason: "opening", note: note)
    end
  end
end
