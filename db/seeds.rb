# Demo data: a wholesale electricals shop with six markets, four brands and a few weeks of trade.
# Every stock figure and balance below is produced by posting documents, never by typing a number.
if User.exists?
  puts "Already seeded"
  return
end

Current.device = "seed"
srand(42)
shop = ShopSetting.current
shop.update!(name: "Shree Ganesh Electricals", legal_name: "Shree Ganesh Electricals Pvt Ltd", gstin: Gstin.with_checksum("27AAGCS1234F1Z"),
             state_code: "27", address: "14, Lohar Chawl, Kalbadevi, Mumbai 400002", phone: "919820012345",
             email: "accounts@shreeganesh.example", upi_id: "shreeganesh@okhdfc", credit_days: 30,
             bank_details: "HDFC Bank · A/c 50200012345678 · IFSC HDFC0000123")
shop.update_columns(gstin: nil) unless Gstin.valid?(shop.gstin)

pw = "hisaab123"
owner    = User.create!(name: "Rajesh Mehta", email_address: "owner@hisaab.test", password: pw, role: "owner", phone: "919820000001")
accounts = User.create!(name: "Priya Nair", email_address: "accounts@hisaab.test", password: pw, role: "accounts")
counter  = User.create!(name: "Sunil Patil", email_address: "counter@hisaab.test", password: pw, role: "counter")
salesmen = [
  User.create!(name: "Amit Yadav", email_address: "amit@hisaab.test", password: pw, role: "salesman", phone: "919820000011"),
  User.create!(name: "Imran Shaikh", email_address: "imran@hisaab.test", password: pw, role: "salesman", phone: "919820000012")
]
driver = User.create!(name: "Ramesh Gaikwad", email_address: "delivery@hisaab.test", password: pw, role: "delivery", phone: "919820000021")
User.create!(name: "CA Deshpande & Co", email_address: "ca@hisaab.test", password: pw, role: "ca")
Current.session = owner.sessions.create!(user_agent: "seed", ip_address: "127.0.0.1")

markets = [["Lamington Road", 1], ["Dadar", 2], ["Andheri", 3], ["Thane", 4], ["Vashi", 5], ["Bhiwandi", 6]].each_with_index.map do |(n, wd), i|
  Market.create!(name: n, delivery_weekday: wd, position: i, salesman: salesmen[i % 2])
end

brands = {
  "Philips" => [24, "claims.west@philips.example"], "Havells" => [24, "service@havells.example"],
  "Syska" => [12, "warranty@syska.example"], "Wipro" => [24, "lighting.claims@wipro.example"]
}.to_h { |n, (w, c)| [n, Brand.create!(name: n, warranty_months: w, claim_contact: c)] }
brands.each_value { |b| Supplier.create!(name: "#{b.name} Distributor – Mumbai", brand: b, state_code: "27", phone: "9122#{rand(10**8).to_s.rjust(8, '0')}") }
Supplier.create!(name: "Polycab Wires (Gujarat)", gstin: nil, state_code: "24")

catalog = [
  # brand, sku, name, watt, hsn, gst, mrp, wholesale, purchase, aliases
  ["Philips", "PH-B9", "Stellar Bright LED Bulb 9W", "9W", "85395000", 12, 120, 62, 52, "philips 9w, 9 watt bulb, 9w bulb, led 9"],
  ["Philips", "PH-B12", "Stellar Bright LED Bulb 12W", "12W", "85395000", 12, 160, 84, 71, "philips 12w, 12 watt bulb"],
  ["Philips", "PH-BT20", "LED Batten 20W 4ft", "20W", "94051000", 18, 450, 238, 205, "20w batten, batten 20, tubelight 20w, tube 20w"],
  ["Philips", "PH-PL15", "Slim Panel Light 15W Round", "15W", "94051000", 18, 950, 520, 455, "panel 15w, 15w panel"],
  ["Havells", "HV-B9", "Adore LED Bulb 9W", "9W", "85395000", 12, 115, 58, 49, "havells 9w"],
  ["Havells", "HV-FAN48", "Efficiencia Neo Ceiling Fan 1200mm", "50W", "84145110", 18, 3650, 2380, 2120, "ceiling fan, fan 48, efficiencia"],
  ["Havells", "HV-MCB32", "MCB SP 32A C-curve", nil, "85362010", 18, 420, 236, 205, "mcb 32, 32a mcb, mcb"],
  ["Havells", "HV-W15", "Lifeline Plus 1.5 sq mm Wire 90m", nil, "85444999", 18, 2290, 1520, 1395, "1.5 wire, 1.5mm wire, wire 1.5"],
  ["Syska", "SY-B9", "SSK LED Bulb 9W", "9W", "85395000", 12, 99, 48, 40, "syska 9w"],
  ["Syska", "SY-BT20", "LED Batten 20W", "20W", "94051000", 18, 380, 196, 168, "syska batten"],
  ["Syska", "SY-STR5", "LED Strip 5m Warm White", nil, "94054900", 18, 799, 410, 350, "strip light, led strip"],
  ["Wipro", "WP-B10", "Garnet LED Bulb 10W", "10W", "85395000", 12, 110, 57, 48, "wipro 10w, 10w bulb"],
  ["Wipro", "WP-SL24", "Garnet Street Light 24W", "24W", "94054900", 18, 2100, 1150, 990, "street light"],
  ["Wipro", "WP-SW6", "Northwest 6A Switch (box of 10)", nil, "85365090", 18, 450, 265, 228, "switch 6a, 6 amp switch"]
]
products = catalog.map do |b, sku, n, w, hsn, g, mrp, ws, pu, al|
  Product.create!(brand: brands[b], sku: sku, name: n, wattage: w, hsn: hsn, gst_rate: g, mrp: mrp, retail: (mrp * 0.85).round,
                  wholesale: ws, purchase: pu, aliases: al, reorder_level: 0)
end

# opening purchases, so stock comes from a document
Supplier.where.not(brand_id: nil).each_with_index do |sup, i|
  items = products.select { _1.brand_id == sup.brand_id }.map { { product: _1, quantity: [700, 900, 1200].sample, rate_paise: _1.purchase_paise } }
  Stock::PurchaseEntry.call(supplier: sup, bill_no: "OPN-#{100 + i}", bill_date: Date.current - 40, items: items)
end

shops = ["Gala Electricals", "New Laxmi Light House", "Jai Ambe Electric", "Royal Lighting", "Patel Hardware & Electricals",
         "Om Sai Electricals", "Krishna Light Point", "Bombay Electric Stores", "Shiv Shakti Traders", "Mahavir Lights",
         "Siddhivinayak Electric", "A-One Electricals", "Balaji Light House", "National Electric Co", "Star Lighting Solutions",
         "Vijay Electricals", "Navkar Traders", "Hari Om Electric", "Sagar Electricals", "Modern Light Centre"]
gstins = %w[27AAACG1234A1Z 27AABCN2345B1Z 27AAFCJ3456C1Z 27AAJCR4567D1Z 27AAKCB5678E1Z 27AAPCO6789F1Z].map { Gstin.with_checksum(_1) }
customers = shops.each_with_index.map do |s, i|
  Customer.create!(shop_name: s, owner_name: %w[Ketan Ramesh Bharat Suresh Dinesh Mahesh Jignesh Nilesh Prakash Mukesh][i % 10] + " " + %w[Shah Patel Jain Gupta Mehta][i % 5],
                   phone: "98#{(20_000_000 + i * 1_234_567).to_s[0, 8]}", market: markets[i % 6], credit_limit: [50_000, 100_000, 200_000][i % 3],
                   address: "Shop #{i + 3}, #{markets[i % 6].name}, Mumbai", marketing_opt_in: i.even?,
                   price_tier: i == 19 ? "retail" : "wholesale")
end
customers.each { |c| c.update_columns(gstin: nil) }
gstins.each_with_index { |g, i| customers[i].update!(gstin: g) if Gstin.valid?(g) }
interstate = Customer.create!(shop_name: "Surat Light Mart", owner_name: "Hitesh Desai", phone: "9825011122", gstin: Gstin.with_checksum("24AAHCS4321K1Z"),
                              state_code: "24", address: "Ring Road, Surat, Gujarat", market: markets[5], credit_limit: 300_000)
walkin = Customer.create!(code: "CASH", shop_name: "Cash customer (counter)", phone: "9100000000", price_tier: "retail")

# six weeks of bills and collections
(35).downto(1).each do |ago|
  date = Date.current - ago
  next if date.sunday?
  customers.sample(rand(2..4)).each do |c|
    items = products.sample(rand(1..4)).map { { product: _1, quantity: [5, 10, 10, 20, 25, 50].sample } }
    begin
      Invoicing::Post.call(customer: c, items: items, date: date, channel: %w[salesman whatsapp counter].sample)
    rescue Invoicing::Post::Error
      next
    end
  end
  customers.sample(rand(1..3)).each do |c|
    bal = c.balance_paise
    next unless bal.positive?
    amt = [bal, [(bal * [0.3, 0.5, 1.0].sample).round(-4), 10_000].max].min
    Payments::Record.call(customer: c, amount_paise: amt, mode: %w[cash upi upi cheque].sample, reference: "CHQ#{rand(100_000..999_999)}", received_on: date)
  end
end
Invoicing::Post.call(customer: interstate, items: [{ product: products[5], quantity: 4 }, { product: products[7], quantity: 3 }], allow_negative_stock: true, date: Date.current - 3)
Invoicing::Post.call(customer: walkin, items: [{ product: products[0], quantity: 4 }], inclusive: true, date: Date.current)

# replacements: some swapped within warranty, a claim sent to Philips
6.times do
  inv = Invoice.posted.where.not(customer: walkin).order("RANDOM()").first
  line = inv.lines.first
  Replacements::Intake.call(customer: inv.customer, product: line.product, outcome: "swapped", defect: ["Not glowing", "Flickering", "Burnt driver"].sample)
rescue Replacements::Intake::Error
  next
end
if (philips = Replacement.awaiting.joins(:product).where(products: { brand_id: brands["Philips"].id })).any?
  claim = Claims::Batch.build(brands["Philips"], philips.to_a)
  Claims::Batch.dispatch!(claim, challan_no: "DC-0412", sent_on: Date.current - 50)
end

# today's dispatch for the market whose day it is (or Lamington Road)
m = markets.find(&:today?) || markets.first
run = DispatchRun.create!(market: m, run_date: Date.current, delivery_person: driver, vehicle: "MH-01-AB-4521")
Invoice.posted.undispatched.joins(:customer).where(customers: { market_id: m.id }).where(invoice_date: (Date.current - 4)..).each_with_index do |inv, i|
  run.deliveries.create!(invoice: inv, position: i)
end

Stock::Reorder.apply!(Stock::Reorder.suggestions)
Order.create!(customer: customers[2], channel: "whatsapp", raw_message: "Bhai 9w philips 50 pc aur 20w batten 10 bhej do", status: "draft")
puts "Seeded: #{Invoice.count} invoices, #{Payment.count} payments, #{Replacement.count} replacements. Login owner@hisaab.test / #{pw}"
