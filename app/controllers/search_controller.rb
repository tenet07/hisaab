class SearchController < ApplicationController
  PAGES = [
    ["Counter bill", "/counter", :invoice_post], ["Order queue", "/orders", :orders], ["New invoice", "/invoices/new", :invoice_post],
    ["Record payment", "/payments/new", :payments], ["New replacement", "/replacements/new", :replacements],
    ["Check warranty", "/replacements/warranty", :replacements], ["Brand claims", "/brand_claims", :claims],
    ["Stock", "/stock", :stock_lookup], ["Reorder suggestions", "/products/reorder", :products_edit],
    ["Purchase entry", "/purchases/new", :purchases], ["Stock count", "/stock_counts", :counts],
    ["Today's dispatch", "/dispatch_runs", :dispatch], ["WhatsApp inbox", "/whatsapp/messages", :whatsapp],
    ["Dues by market", "/reports/dues", :reports], ["GSTR-1", "/reports/gstr1", :reports], ["GSTR-3B", "/reports/gstr3b", :reports],
    ["Tally export", "/reports/tally", :exports], ["Day book", "/reports/day_book", :reports], ["Approvals", "/approvals", :approvals_view],
    ["Settings", "/settings", :settings], ["Users", "/users", :settings], ["Audit trail", "/audit_events", :audit]
  ].freeze

  def index
    q = params[:q].to_s.strip
    items = []
    PAGES.each do |title, url, perm|
      next unless can?(perm) || (perm == :stock_lookup && can?(:stock))
      items << { group: "Go to", title: title, url: url } if q.blank? || title.downcase.include?(q.downcase)
    end
    if q.length >= 2
      if can?(:customers)
        Customer.active.search(q).includes(:market).limit(6).each do |c|
          items << { group: "Customers", title: c.shop_name, sub: [c.code, c.market&.name].compact.join(" · "), url: "/customers/#{c.id}" }
        end
      end
      if can?(:invoices)
        Invoice.where("number ILIKE ? OR bill_to_name ILIKE ?", "%#{q}%", "%#{q}%").recent.limit(5).each do |i|
          items << { group: "Invoices", title: i.number, sub: "#{i.bill_to_name} · #{Money.format(i.total_paise)}", url: "/invoices/#{i.id}" }
        end
      end
      Product.active.search(q).limit(6).each do |p|
        items << { group: "Products", title: p.display_name, sub: "#{p.sku} · #{p.stock} in stock", url: can?(:products) ? "/products/#{p.id}" : "/stock?q=#{p.sku}" }
      end
    end
    render json: items.first(30)
  end
end
