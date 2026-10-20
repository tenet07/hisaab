module Mobile
  # What field staff capture, online or replayed later from the phone's outbox. Every capture
  # carries a client_uuid, so a retried sync never creates a second order or payment.
  module Capture
    module_function

    def order(customer:, lines:, notes: nil, client_uuid: nil)
      if client_uuid.present? && (o = Order.find_by(client_uuid: client_uuid))
        return o
      end
      rows = lines.respond_to?(:to_unsafe_h) ? lines.to_unsafe_h.values : Array(lines.is_a?(Hash) ? lines.values : lines)
      rows = rows.select { _1["product_id"].present? && _1["quantity"].to_i.positive? }
      raise ArgumentError, "Add at least one item" if rows.empty?
      Order.create!(customer: customer, channel: "salesman", status: "confirmed", notes: notes, created_by: Current.user, client_uuid: client_uuid.presence,
                    lines_attributes: rows.map { { product_id: _1["product_id"], quantity: _1["quantity"].to_i, confidence: 1 } })
    end

    def payment(customer:, amount:, mode:, reference: nil, client_uuid: nil)
      existed = client_uuid.present? && Payment.exists?(client_uuid: client_uuid)
      pay = Payments::Record.call(customer: customer, amount_paise: Money.to_paise(amount), mode: mode.presence || "cash",
                                  reference: reference, client_uuid: client_uuid)
      WhatsappNotifier.receipt(pay) unless existed
      pay
    end

    def replacement(customer:, product_id:, outcome:, defect: nil, client_uuid: nil)
      Replacements::Intake.call(customer: customer, product: Product.find(product_id), outcome: outcome.presence || "swapped",
                                defect: defect, channel: "route", client_uuid: client_uuid)
    end
  end
end
