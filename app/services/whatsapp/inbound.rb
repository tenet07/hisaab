module Whatsapp
  # Routes a customer's incoming message: balance queries answer themselves, anything that looks
  # like an order becomes a draft in the order queue (AI-parsed), the rest waits in the inbox.
  module Inbound
    BALANCE = /\A\s*(bal(ance)?|baki|baaki|hisab|hisaab|due|outstanding|kitna\s+(baki|dena))\b/i
    STATEMENT = /\A\s*(statement|ledger|khata)\b/i
    STOP = /\A\s*(stop|unsubscribe)\s*\z/i
    module_function

    def handle(phone:, text:, provider_id: nil)
      Current.device = "whatsapp"
      return if provider_id && WhatsappMessage.exists?(provider_message_id: provider_id)
      customer = Customer.find_by_phone(phone)
      msg = WhatsappMessage.create!(customer: customer, phone: phone.to_s.gsub(/\D/, ""), direction: "in", category: "service",
                                    body: text.to_s, status: "received", provider_message_id: provider_id)
      unless customer
        WhatsappNotifier.text(nil, "Namaste! This number isn't registered with #{ShopSetting.current.name} yet. We'll call you back shortly.", phone: msg.phone)
        return msg
      end
      case text.to_s
      when BALANCE then WhatsappNotifier.balance_reply(customer)
      when STATEMENT then WhatsappNotifier.statement(customer, from: Date.current.beginning_of_month, to: Date.current)
      when STOP
        customer.update!(marketing_opt_in: false)
        WhatsappNotifier.text(customer, "Done — you won't get offers any more. Bills and receipts will still come here.")
      else
        if order_like?(text)
          order = OrderParser.draft!(customer: customer, text: text, channel: "whatsapp")
          msg.update!(document: order)
          WhatsappNotifier.order_ack(order) if order.lines.any?
        end
      end
      msg
    end

    def order_like?(text) = text.to_s.match?(/\d/) && text.to_s.length.between?(3, 1500)
  end
end
