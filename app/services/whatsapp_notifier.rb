# Every outbound WhatsApp message the shop sends. Business-initiated messages use approved
# templates (utility for invoices/receipts/reminders, marketing only for opted-in broadcasts);
# replies inside a customer's 24-hour window are plain service text.
module WhatsappNotifier
  include Rails.application.routes.url_helpers
  extend self

  # Indicative Meta per-message rates for India (paise), for the owner's cost view
  COST = { "utility" => 13, "marketing" => 88, "service" => 0 }.freeze

  def invoice(inv)
    c = inv.customer
    queue(c, category: "utility", template: "invoice_issued", document: inv,
          params: [c.owner_name.presence || c.shop_name, inv.number, Money.format(inv.total_paise), inv.due_date.strftime("%d %b"),
                   Money.format(c.balance_paise)],
          document_url: public_doc_url(inv), filename: "#{inv.number.tr('/', '-')}.pdf",
          body: "Namaste #{c.owner_name.presence || c.shop_name}, invoice #{inv.number} for #{Money.format(inv.total_paise)} is attached. " \
                "Due by #{inv.due_date.strftime('%d %b')}. Your balance is now #{Money.format(c.balance_paise)}." \
                "#{"\nPay by UPI: #{inv.upi_uri}" if inv.upi_uri}")
  end

  def delivered(delivery)
    inv = delivery.invoice
    c = inv.customer
    queue(c, category: "utility", template: "delivery_done", document: inv,
          params: [inv.number, delivery.delivered_at&.strftime("%I:%M %p"), delivery.delivered_by&.name],
          body: "Delivered: invoice #{inv.number} reached you at #{delivery.delivered_at&.strftime('%I:%M %p')}" \
                "#{" (#{delivery.delivered_by.name})" if delivery.delivered_by}. Reply here if anything is short or damaged.")
  end

  def receipt(pay)
    c = pay.customer
    applied = pay.allocations.includes(:invoice).map { "#{_1.target_label} #{Money.format(_1.amount_paise)}" }.join(", ")
    queue(c, category: "utility", template: "payment_receipt", document: pay,
          params: [Money.format(pay.amount_paise), pay.mode_label, pay.number, Money.format(c.balance_paise)],
          body: "Received #{Money.format(pay.amount_paise)} by #{pay.mode_label} (receipt #{pay.number}). " \
                "#{"Applied to #{applied}. " if applied.present?}Balance now #{Money.format(c.balance_paise)}. Thank you!")
  end

  def credit_note(cn)
    c = cn.customer
    queue(c, category: "utility", template: "credit_note_issued", document: cn,
          params: [cn.number, Money.format(cn.total_paise), cn.invoice.number, Money.format(c.balance_paise)],
          document_url: public_doc_url(cn), filename: "#{cn.number.tr('/', '-')}.pdf",
          body: "Credit note #{cn.number} for #{Money.format(cn.total_paise)} (#{cn.reason_label.downcase}) on invoice #{cn.invoice.number}. " \
                "Balance now #{Money.format(c.balance_paise)}.")
  end

  def overdue_reminder(c)
    overdue = c.open_items.select(&:overdue?)
    return if overdue.empty?
    oldest = overdue.first
    queue(c, category: "utility", template: "overdue_reminder", document: oldest,
          params: [c.owner_name.presence || c.shop_name, Money.format(overdue.sum(&:outstanding_paise)), oldest.number, oldest.days_overdue],
          body: "Reminder: #{Money.format(overdue.sum(&:outstanding_paise))} is overdue on #{overdue.size} bill(s); the oldest, " \
                "#{oldest.number}, is #{oldest.days_overdue} days late. Please arrange payment. Reply BAL any time for your balance.")
  end

  def statement(c, from:, to:)
    queue(c, category: "utility", template: "monthly_statement",
          params: [from.strftime("%B %Y"), Money.format(c.balance_on(to))],
          document_url: public_statement_url(c, from, to), filename: "statement-#{from.strftime('%Y-%m')}.pdf",
          body: "Your statement for #{from.strftime('%B %Y')} is attached. Closing balance #{Money.format(c.balance_on(to))}.")
  end

  def balance_reply(c)
    open = c.open_items
    lines = open.first(5).map { "• #{_1.number} (#{_1.invoice_date.strftime('%d %b')}): #{Money.format(_1.outstanding_paise)}#{' ⚠ overdue' if _1.overdue?}" }
    queue(c, category: "service",
          body: "#{c.shop_name}: balance #{Money.format(c.balance_paise)}.\n#{lines.join("\n")}#{"\n…and #{open.size - 5} more" if open.size > 5}".strip)
  end

  def order_ack(order)
    c = order.customer
    lines = order.lines.includes(:product)
    items = lines.select(&:product).map { "#{_1.product.display_name} × #{_1.quantity}" }
    unsure = lines.reject(&:product).map { "“#{_1.source_text}”" }
    queue(c, category: "service", document: order,
          body: "Got your order #{order.number}:\n#{items.join("\n")}#{"\nWe'll call you about: #{unsure.join(', ')}" if unsure.any?}\nWe'll confirm and send the bill shortly.")
  end

  def text(c, body, phone: nil) = queue(c, category: "service", body: body, phone: phone)

  def broadcast(b, customer)
    queue(customer, category: "marketing", template: "market_offer", document: b, params: [b.title, b.body], body: "*#{b.title}*\n#{b.body}")
  end

  private

  def queue(customer, category:, body:, template: nil, document: nil, params: [], document_url: nil, filename: nil, phone: nil)
    msg = WhatsappMessage.create!(customer: customer, phone: phone || customer&.phone, direction: "out", category: category,
                                  template: template, body: body, document: document, cost_paise: COST[category],
                                  payload: { params: params, document_url: document_url, filename: filename }.compact)
    WhatsappSendJob.perform_later(msg.id)
    msg
  end

  def public_doc_url(record)
    host_url("/d/#{record.to_sgid(expires_in: 30.days, for: 'public_doc')}")
  end

  def public_statement_url(c, from, to)
    host_url("/d/#{c.to_sgid(expires_in: 30.days, for: 'public_doc')}?from=#{from}&to=#{to}")
  end

  def host_url(path)
    host = ENV["APP_HOST"].presence || Rails.application.config.action_mailer.default_url_options&.dig(:host) || "localhost:3000"
    "#{host.start_with?('http') ? host : "https://#{host}"}#{path}"
  end
end
