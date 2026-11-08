# Demo data for trying the app locally. A real installation starts empty
# and asks for the owner on first open (see SetupsController).
return unless Rails.env.development? || ENV["DEMO_DATA"] == "1"

# Demo data. Replace with the real product list, customers and opening
# balances during the week 1-2 digitisation sprint.
ShopSetting.current.update!(name: "Solanki Electricals", gstin: "06ABCPS1234F1Z5",
  address: "Shop 14, Sadar Bazaar\nGurgaon, Haryana 122001", phone: "9811000000", invoice_prefix: "SE",
  upi_id: "solanki.elec@okhdfcbank", bank_name: "HDFC Bank", bank_account: "50100123456789", bank_ifsc: "HDFC0001234",
  bill_terms: "Goods once sold will not be taken back.\nWarranty as per manufacturer's terms.\nSubject to Gurgaon jurisdiction.")
owner = User.find_or_create_by!(name: "Owner") { |u| u.role = "owner"; u.password = "1234" }
accounts = User.find_or_create_by!(name: "Accounts") { |u| u.role = "accounts"; u.password = "1234" }
salesman = User.find_or_create_by!(name: "Ramesh") { |u| u.role = "salesman"; u.password = "1234" }
User.find_or_create_by!(name: "Counter") { |u| u.role = "counter"; u.password = "1234" }
d1 = User.find_or_create_by!(name: "Delivery 1") { |u| u.role = "delivery"; u.password = "1234" }
d2 = User.find_or_create_by!(name: "Delivery 2") { |u| u.role = "delivery"; u.password = "1234" }

markets = {
  "Sadar Bazaar" => "Mon", "Sohna Road" => "Tue", "Palam Vihar" => "Wed",
  "Badshahpur" => "Thu", "Manesar" => "Fri", "Pataudi" => "Sat"
}.each_with_index.map do |(name, day), i|
  Market.find_or_create_by!(name: name) { |m| m.delivery_day = day; m.salesman = salesman; m.delivery_person = i.even? ? d1 : d2 }
end

P = ->(rupees) { Shop::Money.paise(rupees) }
products = [
  # sku, name, brand, hsn, gst, retail(MRP incl), wholesale(excl), warranty, reorder, opening
  ["PH-LED-9W",  "LED Bulb 9W",          "Philips", "8539", 1800, "99",   "62",   12, 200, 600],
  ["PH-LED-12W", "LED Bulb 12W",         "Philips", "8539", 1800, "149",  "94",   12, 150, 400],
  ["PH-BAT-20W", "LED Batten 20W 4ft",   "Philips", "9405", 1800, "449",  "290",  24, 50,  120],
  ["SY-LED-9W",  "LED Bulb 9W",          "Syska",   "8539", 1800, "89",   "55",   12, 200, 500],
  ["SY-PNL-15W", "Round Panel 15W",      "Syska",   "9405", 1800, "599",  "360",  24, 30,  80],
  ["HV-FAN-1200","Ceiling Fan 1200mm",   "Havells", "8414", 1800, "2890", "2050", 24, 10,  25],
  ["HV-MCB-32A", "MCB 32A SP",           "Havells", "8536", 1800, "310",  "205",  0,  40,  150],
  ["WP-STR-5M",  "LED Strip 5m",         "Wipro",   "9405", 1800, "699",  "420",  6,  20,  60]
].map do |sku, name, brand, hsn, gst, mrp, wh, war, reo, open|
  p = Product.find_or_create_by!(sku: sku) do |x|
    x.assign_attributes(name: name, brand: brand, hsn: hsn, gst_bp: gst, retail_price_paise: P[mrp],
                        wholesale_price_paise: P[wh], price_includes_tax: false, warranty_months: war,
                        reorder_level: reo)
  end
  Books.opening_stock(p, open, user: accounts) if p.stock_movements.none?
  p
end

shops = [
  ["Gupta Electricals", "9811000001", "06AABCG1234A1Z5", 0],
  ["Sharma Light House", "9811000002", nil, 0],
  ["New Bharat Electric", "9811000003", "06AACCN5678B1Z2", 1],
  ["Jain & Sons", "9811000004", nil, 2],
  ["Delhi Lighting Co", "9811000005", "07AADCD9999C1Z9", 3], # out of state -> IGST
  ["Yadav Hardware", "9811000006", nil, 4],
  ["Pataudi Electricals", "9811000007", nil, 5]
].map do |name, phone, gstin, mi|
  c = Customer.find_or_create_by!(name: name) do |x|
    x.address = "#{10 + mi * 7}, Main Road, #{markets[mi].name}\nGurgaon, Haryana"
    x.assign_attributes(phone: phone, gstin: gstin, market: markets[mi], price_tier: "wholesale",
                        credit_limit_paise: P["50000"])
  end
  Books.opening_balance(c, P["12500"] * (mi + 1), user: accounts, date: Date.current - (30 * mi)) if c.ledger_entries.none?
  c
end

if Invoice.none?
  Books.create_invoice(customer: shops[0], user: accounts,
                       items: [{ product: products[0], qty: 100 }, { product: products[2], qty: 10 }])
  Books.create_invoice(customer: shops[4], user: accounts, items: [{ product: products[5], qty: 4 }])
  Books.record_payment(customer: shops[0], amount_paise: P["10000"], mode: "upi", ref: "UPI-4471", user: salesman)
  Books.replace(customer: shops[1], product: products[0], qty: 3, user: salesman, sold_on: Date.current - 40)

  # Today's run for Delivery 1, so the delivery phone has stops to show.
  [[shops[0], [[products[1], 50], [products[4], 6]]],
   [shops[2], [[products[3], 120], [products[6], 20]]],
   [shops[5], [[products[2], 12], [products[7], 4]]]].each_with_index do |(cust, lines), i|
    inv = Books.create_invoice(customer: cust, user: accounts, channel: "salesman", deliver: true,
                               items: lines.map { |p, q| { product: p, qty: q } })
    Books.assign_delivery(inv.delivery, to: d1, run_date: Date.current, user: owner)
    Books.load_delivery(inv.delivery, loaded: {}, user: d1) if i.zero?
  end
end
if Supplier.none?
  phil = Supplier.create!(name: "Signify Distributor Gurgaon", brands: "Philips", gstin: "06AAACS1234D1Z1", credit_days: 30)
  Supplier.create!(name: "Syska Wholesale NCR", brands: "Syska, Wipro", gstin: "07AABCS5678E1Z3", credit_days: 21) # Delhi: IGST
  Supplier.create!(name: "Havells Stockist", brands: "Havells", credit_days: 45)
  Books.supplier_opening(phil, P["85000"], user: owner, date: Date.current - 40)
  Books.create_purchase(supplier: phil, number: "SDG/2611/0457", date: Date.current - 3, user: accounts,
                        items: [{ product: products[0], qty: 200, rate_paise: P["60.50"] },
                                { product: products[2], qty: 40, rate_paise: P["282"] }])
end
puts "Seeded: #{User.count} users, #{Market.count} markets, #{Customer.count} customers, #{Product.count} products"
