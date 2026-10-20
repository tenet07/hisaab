module M
  # The phone's offline outbox replays here. Each item is processed on its own so one bad
  # entry doesn't block the rest; the phone drops items that come back ok or permanently failed.
  class SyncController < BaseController
    skip_forgery_protection only: :push

    # Everything the phone needs to keep working without signal
    def catalog
      customers = Current.user.owner? ? Customer.active : Customer.active.where(market: Current.user.markets)
      render json: {
        at: Time.current.iso8601,
        products: Product.active.includes(:brand).map { { id: _1.id, label: _1.display_name, sku: _1.sku, search: [_1.display_name, _1.sku, _1.aliases].join(" ").downcase } },
        customers: can?(:visits) ? customers.with_balance.map { { id: _1.id, name: _1.shop_name, balance: _1.balance_paise } } : []
      }
    end

    def push
      results = Array(params[:items]).map do |raw|
        item = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
        uuid = item["client_uuid"]
        begin
          p = item["params"] || {}
          perm = { "order" => :orders, "payment" => :payments, "replacement" => :replacements, "drop" => :deliveries }[item["kind"]]
          raise ArgumentError, "Your role can't do that" unless perm && can?(perm)
          doc = case item["kind"]
                when "order" then Mobile::Capture.order(customer: Customer.find(p["customer_id"]), lines: p["lines"] || {}, notes: p["notes"], client_uuid: uuid)
                when "payment" then Mobile::Capture.payment(customer: Customer.find(p["customer_id"]), amount: p["amount"], mode: p["mode"], reference: p["reference"], client_uuid: uuid)
                when "replacement" then Mobile::Capture.replacement(customer: Customer.find(p["customer_id"]), product_id: p["product_id"], outcome: p["outcome"], defect: p["defect"], client_uuid: uuid)
                when "drop" then drop(p, uuid)
                else raise ArgumentError, "Unknown item"
                end
          { client_uuid: uuid, ok: true, number: doc.try(:number) }
        rescue ActiveRecord::RecordNotFound, ArgumentError, Payments::Record::Error, Replacements::Intake::Error, Dispatch::Drop::Error,
               Invoicing::CreditNote::Error, ActiveRecord::RecordInvalid => e
          # kept on the phone as "needs attention", and shown to the office, so nothing collected is lost silently
          AuditEvent.log!(Current.user, "sync_rejected", { "kind" => item["kind"], "error" => e.message,
                                                           "params" => (item["params"] || {}).except("photo_data"), "saved_at" => item["saved_at"] })
          { client_uuid: uuid, ok: false, permanent: true, error: e.message }
        end
      end
      render json: { results: results }
    end

    private

    def drop(p, uuid)
      d = Delivery.find(p["delivery_id"])
      photo = nil
      if p["photo_data"].to_s.start_with?("data:image")
        data = Base64.decode64(p["photo_data"].split(",", 2).last)
        photo = { io: StringIO.new(data), filename: "drop-#{d.id}.jpg", content_type: "image/jpeg" }
      end
      Dispatch::Drop.complete!(d, otp: p["otp"].presence, photo: photo, shortfall: p["shortfall"] || {},
                                  payment: { amount_paise: Money.to_paise(p["amount"]).to_i, mode: p["mode"], reference: p["reference"] },
                                  failed_reason: p["failed_reason"], client_uuid: uuid)
      d.invoice
    end
  end
end
