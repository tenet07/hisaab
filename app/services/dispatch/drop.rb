module Dispatch
  # Closes one drop on a route: proof (photo or the customer's OTP), any shortfall becomes a
  # credit note, cash/UPI collected on the spot is recorded with a receipt.
  module Drop
    class Error < StandardError; end
    MAX_OTP_TRIES = 5
    module_function

    # shortfall: { invoice_line_id => qty }, payment: { amount_paise:, mode:, reference: }
    def complete!(delivery, otp: nil, photo: nil, shortfall: {}, payment: nil, failed_reason: nil, client_uuid: nil)
      return delivery if delivery.closed? && client_uuid.present? && delivery.client_uuid == client_uuid
      raise Error, "This drop is already closed" if delivery.closed?
      raise Error, "This route hasn't been started by the office yet" if delivery.dispatch_run.status == "planned"
      raise Error, "Too many wrong OTPs — take a photo of the delivered goods instead" if otp.present? && delivery.otp_failures >= MAX_OTP_TRIES
      if otp.present? && !ActiveSupport::SecurityUtils.secure_compare(otp.to_s.strip, delivery.otp_code.to_s)
        delivery.increment!(:otp_failures)
        raise Error, "OTP doesn't match — ask the customer for the 4-digit code we sent them"
      end
      Delivery.transaction do
        if failed_reason.present?
          delivery.update!(status: "failed", notes: failed_reason, delivered_by: Current.user, delivered_at: Time.current, client_uuid: client_uuid)
          run = delivery.dispatch_run
          run.update!(status: "done") if run.deliveries.reload.all?(&:closed?)
          return delivery
        end
        if otp.present?
          delivery.otp_verified = true
          delivery.proof = "otp"
        elsif photo.present?
          delivery.photo.attach(photo)
          delivery.proof = "photo"
        else
          raise Error, "Take a photo of the delivered goods or enter the customer's OTP"
        end
        short = shortfall.to_h.transform_keys(&:to_i).transform_values(&:to_i).select { _2.positive? }
        if short.any?
          lines = delivery.invoice.lines.index_by(&:id)
          Invoicing::CreditNote.call(invoice: delivery.invoice, reason: "shortfall", restock_bucket: "sellable",
                                     items: short.filter_map { |id, q| lines[id] && { invoice_line: lines[id], quantity: q } },
                                     notes: "Short at delivery, returned in van")
        end
        delivery.update!(status: short.any? ? "partial" : "delivered", delivered_by: Current.user, delivered_at: Time.current, client_uuid: client_uuid)
        if payment && payment[:amount_paise].to_i.positive?
          pay = Payments::Record.call(customer: delivery.customer, amount_paise: payment[:amount_paise], mode: payment[:mode].presence || "cash",
                                      reference: payment[:reference], client_uuid: client_uuid && "#{client_uuid}-pay")
          WhatsappNotifier.receipt(pay)
        end
        WhatsappNotifier.delivered(delivery)
        run = delivery.dispatch_run
        run.update!(status: "done") if run.deliveries.reload.all?(&:closed?)
        delivery
      end
    end
  end
end
