module ApplicationHelper
  # A demo installation (DEMO_DATA=1): sample shop, PIN 1234 for everyone, data not kept.
  def demo? = ENV["DEMO_DATA"] == "1"

  def rs(paise) = Shop::Money.format(paise.to_i)
  def rs_input(paise) = paise.to_i.zero? ? "" : format("%.2f", paise.to_i / 100.0)
  def gst_pct(bp) = "#{bp / 100}%"
  def bucket_name(b) = b.to_s.tr("_", " ").capitalize

  def shop = ShopSetting.current

  # UPI deep link: any UPI app opens with the payee and exact amount filled in.
  def upi_uri(vpa, payee, amount_paise, note)
    # pa stays literal (validated as name@bank): some UPI apps reject a %40-encoded "@".
    q = { pn: payee.to_s.first(40), am: format("%.2f", amount_paise / 100.0), cu: "INR", tn: note.to_s.first(40) }
    "upi://pay?pa=#{vpa}&" + q.map { |k, v| "#{k}=#{ERB::Util.url_encode(v)}" }.join("&")
  end

  def upi_qr_svg(uri)
    require "rqrcode"
    RQRCode::QRCode.new(uri, level: :m).as_svg(module_size: 4, standalone: true, use_path: true, viewbox: true,
                                               svg_attributes: { class: "qr", role: "img", "aria-label": "UPI payment QR code" }).html_safe
  end

  # 900 -> "9%", 250 -> "2.5%"
  def rate_pct(bp) = "#{(bp / 100.0).to_s.delete_suffix('.0')}%"

  def state_label(code) = code.present? ? "#{Shop::STATES[code]} (#{code})" : ""
  def shop_name = shop.name

  # Opens WhatsApp with the message ready to send. Works with no API account;
  # swap for the WhatsApp Business API sender once a provider is chosen.
  def wa_link(customer, text)
    return nil unless customer.whatsapp_number
    "https://wa.me/#{customer.whatsapp_number}?text=#{ERB::Util.url_encode(text)}"
  end

  def invoice_message(inv)
    lines = inv.lines.map { |l| "• #{l.product.name} (#{l.product.brand}) × #{l.qty} = #{rs(l.total_paise)}" }
    <<~TXT.strip
      #{shop_name}
      Bill #{inv.number} dated #{inv.date.strftime('%d %b %Y')}
      #{lines.join("\n")}
      Total: #{rs(inv.total_paise)}
      Your balance now: #{rs(inv.customer.balance_paise)}
      #{delivery_code_line(inv)}Thank you!
    TXT
  end

  def delivery_code_line(inv)
    d = inv.delivery
    return "" unless d&.open?
    "Delivery code: #{d.otp}. Give it to our delivery person only after checking the goods.\n"
  end

  def receipt_message(pay)
    <<~TXT.strip
      #{shop_name}
      Received #{rs(pay.amount_paise)} by #{pay.mode.upcase} on #{pay.date.strftime('%d %b %Y')} (ref #{pay.ref}).
      Balance now: #{rs(pay.customer.balance_paise)}
      Thank you!
    TXT
  end

  def reminder_message(customer)
    oldest = customer.open_items.first
    <<~TXT.strip
      #{shop_name}
      Namaste #{customer.owner_name.presence || customer.name}, your balance is #{rs(customer.balance_paise)}.
      #{oldest ? "Oldest unpaid: #{oldest[:ref]} of #{oldest[:date].strftime('%d %b')} (#{rs(oldest[:due])} due)." : ''}
      Please arrange payment. Thank you!
    TXT
  end

  STATUS_PILL = { "pending" => "", "loaded" => "info", "delivered" => "ok", "partly_delivered" => "warn",
                  "failed" => "due", "cancelled" => "due" }.freeze
  STATUS_TEXT = { "pending" => "To load", "loaded" => "On vehicle", "partly_delivered" => "Partly delivered",
                  "failed" => "Not delivered" }.freeze
  def status_pill(d) = tag.span(STATUS_TEXT[d.status] || d.status.humanize, class: "pill #{STATUS_PILL[d.status]}")

  # ---------------------------------------------------------------- presentation

  # Big amounts: rupees bold, paise small. Screen readers and text search get the
  # full figure from the visually hidden copy.
  def amt(paise, tone: nil, size: nil)
    full = rs(paise)
    whole, ps = full.split(".")
    tag.span(class: ["amt", tone, size].compact.join(" ")) do
      tag.span(aria: { hidden: true }) { safe_join([whole, tag.small(".#{ps}")]) } + tag.span(full, class: "sr-only")
    end
  end

  # Whole rupees only, for dense summaries (₹2,85,414).
  def rs0(paise) = rs(paise).sub(/\.\d\d\z/, "")

  def days_ago(date)
    n = (Date.current - date).to_i
    n <= 0 ? "today" : n == 1 ? "yesterday" : "#{n} days ago"
  end

  def initials(name) = name.to_s.split.first(2).map { _1[0] }.join.upcase

  ICONS = {
    home: '<path d="M3 11l9-7 9 7"/><path d="M5 10v10h14V10"/>',
    users: '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c.8-3.6 3.4-5.5 6.5-5.5s5.7 1.9 6.5 5.5"/><path d="M16 4.6a3.5 3.5 0 010 6.8M18 14.8c1.8.8 3 2.6 3.5 5.2"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    bill: '<path d="M6 3h12v18l-3-2-3 2-3-2-3 2z"/><path d="M9 8h6M9 12h6M9 16h3"/>',
    truck: '<path d="M2 6h11v10H2zM13 10h4l4 4v2h-8"/><circle cx="6" cy="18" r="2"/><circle cx="17" cy="18" r="2"/>',
    box: '<path d="M3 7l9-4 9 4v10l-9 4-9-4z"/><path d="M3 7l9 4 9-4M12 11v10"/>',
    swap: '<path d="M4 8h13l-3-3M20 16H7l3 3"/>',
    tag: '<path d="M3 12V4h8l10 10-8 8z"/><circle cx="7.5" cy="8.5" r="1.5"/>',
    map: '<path d="M9 4l6 2 6-2v14l-6 2-6-2-6 2V6z"/><path d="M9 4v14M15 6v14"/>',
    export: '<path d="M12 3v12M7 10l5 5 5-5"/><path d="M4 17v3h16v-3"/>',
    more: '<circle cx="5" cy="12" r="1.6"/><circle cx="12" cy="12" r="1.6"/><circle cx="19" cy="12" r="1.6"/>',
    logout: '<path d="M14 4h5v16h-5"/><path d="M10 8l-4 4 4 4M6 12h10"/>',
    rupee: '<path d="M6 4h12M6 9h12M8 4c6 0 6 10 0 10H6l9 7"/>',
    phone: '<path d="M5 3h4l2 5-2.5 1.5a11 11 0 006 6L16 13l5 2v4a2 2 0 01-2 2A16 16 0 013 5a2 2 0 012-2z"/>',
    chat: '<path d="M4 20l1.4-4.2A8 8 0 1112 20a8 8 0 01-3.8-1z"/>',
    camera: '<path d="M3 8h4l2-3h6l2 3h4v11H3z"/><circle cx="12" cy="13" r="3.5"/>',
    check: '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
    x: '<path d="M6 6l12 12M18 6L6 18"/>',
    search: '<circle cx="11" cy="11" r="6.5"/><path d="M16 16l4.5 4.5"/>',
    alert: '<path d="M12 3l10 18H2z"/><path d="M12 10v5M12 18v.5"/>',
    print: '<path d="M7 9V3h10v6"/><path d="M7 17H4v-8h16v8h-3"/><path d="M7 14h10v7H7z"/>',
    chevron: '<path d="M9 5l7 7-7 7"/>',
    back: '<path d="M15 5l-7 7 7 7"/>',
    route: '<circle cx="6" cy="19" r="2"/><circle cx="18" cy="5" r="2"/><path d="M6 17V9a4 4 0 014-4h0a4 4 0 014 4v6a4 4 0 004 4h0"/>',
    store: '<path d="M3 9l2-5h14l2 5"/><path d="M4 9v11h16V9"/><path d="M3 9h18M9 20v-6h6v6"/>',
    upload: '<path d="M12 16V4M7 9l5-5 5 5"/><path d="M4 17v3h16v-3"/>',
    gear: '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 00.3 1.8l.1.1a2 2 0 11-2.8 2.8l-.1-.1a1.7 1.7 0 00-1.8-.3 1.7 1.7 0 00-1 1.5V21a2 2 0 11-4 0v-.1a1.7 1.7 0 00-1.1-1.5 1.7 1.7 0 00-1.8.3l-.1.1a2 2 0 11-2.8-2.8l.1-.1a1.7 1.7 0 00.3-1.8 1.7 1.7 0 00-1.5-1H3a2 2 0 110-4h.1a1.7 1.7 0 001.5-1.1 1.7 1.7 0 00-.3-1.8l-.1-.1a2 2 0 112.8-2.8l.1.1a1.7 1.7 0 001.8.3H9a1.7 1.7 0 001-1.5V3a2 2 0 114 0v.1a1.7 1.7 0 001 1.5 1.7 1.7 0 001.8-.3l.1-.1a2 2 0 112.8 2.8l-.1.1a1.7 1.7 0 00-.3 1.8V9a1.7 1.7 0 001.5 1H21a2 2 0 110 4h-.1a1.7 1.7 0 00-1.5 1z"/>',
    key: '<circle cx="8" cy="15" r="4"/><path d="M11 12l9-9M17 6l3 3M14 9l2 2"/>',
    bulb: '<path d="M9 18h6M10 21h4"/><path d="M12 3a6 6 0 00-3.5 10.9c.6.5 1 1.2 1 2.1h5c0-.9.4-1.6 1-2.1A6 6 0 0012 3z"/>'
  }.freeze

  def icon(name, size: 22, cls: nil)
    tag.svg(ICONS.fetch(name).html_safe, class: ["ic", cls].compact.join(" "), width: size, height: size,
            viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", "stroke-width": 1.9,
            "stroke-linecap": "round", "stroke-linejoin": "round", aria: { hidden: true }, focusable: "false")
  end

  # Labels that don't fit a 5-tab phone bar get a short form there.
  SHORT_LABELS = { "Replacements" => "Swaps", "Customers" => "Customers" }.freeze

  def nav_link(label, path, ic, cls: nil, match: nil, short: false)
    on = match ? match.call : current_page?(path)
    text = short ? SHORT_LABELS.fetch(label, label) : label
    link_to path, class: ["nav-i", cls, ("on" if on)].compact.join(" "), aria: { current: (on ? "page" : nil) }, title: (label if text != label) do
      icon(ic) + tag.span(text)
    end
  end

  # Navigation per role: the first few go in the phone tab bar, the rest under "More".
  def nav_items
    u = current_user
    c = controller_name
    if u.delivery?
      [["My run", run_deliveries_path, :route, -> { c == "deliveries" }]]
    elsif u.field?
      [["Shops", customers_path, :users, -> { c == "customers" || c == "payments" }],
       ["New order", new_invoice_path, :plus, -> { c == "invoices" && action_name == "new" }],
       ["Bills", invoices_path, :bill, -> { c == "invoices" && action_name != "new" }],
       ["Stock", products_path, :box, -> { c == "products" }],
       ["Replacements", replacements_path, :swap, -> { c == "replacements" }]]
    else
      items = [["Today", root_path, :home, -> { c == "dashboard" }],
               ["Customers", customers_path, :users, -> { %w[customers payments markets].include?(c) }]]
      items << ["New bill", new_invoice_path, :plus, -> { c == "invoices" && action_name == "new" }] if u.can_bill?
      items += [["Bills", invoices_path, :bill, -> { c == "invoices" && action_name != "new" }],
                ["Dispatch", deliveries_path, :truck, -> { c == "deliveries" }],
                ["Stock", products_path, :box, -> { c == "products" }],
                ["Replacements", replacements_path, :swap, -> { c == "replacements" }],
                ["Claims", claims_path, :tag, -> { %w[claims claim_lines claim_credits].include?(c) }],
                ["Suppliers", suppliers_path, :store, -> { %w[suppliers purchase_bills supplier_payments].include?(c) }],
                ["Markets", markets_path, :map, -> { c == "markets" }]]
      if %w[owner accounts].include?(u.role)
        items << ["Tally", tally_path, :export, -> { c == "tally" }]
        items << ["Import", imports_path, :upload, -> { c == "imports" }]
      end
      if u.owner?
        items << ["Staff", users_path, :users, -> { c == "users" }]
        items << ["Settings", edit_settings_path, :gear, -> { c == "shop_settings" }]
      end
      items
    end
  end

  def role_name(u) = { "counter" => "Counter", "owner" => "Owner", "accounts" => "Accounts",
                       "salesman" => "Salesman", "delivery" => "Delivery" }[u.role] || u.role.humanize

  def back_link(label, path)
    link_to path, class: "back" do
      icon(:back, size: 18) + tag.span(label)
    end
  end
end
