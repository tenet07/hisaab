require "csv"

# Go-live import of products, customers and suppliers from Excel (.xlsx) or CSV.
#
#   result = Importer.new(:products, path, user: owner).run(commit: false)  # preview
#   result = Importer.new(:products, path, user: owner).run(commit: true)   # save
#
# A preview runs every row exactly as a real import would, inside a transaction
# that is rolled back, so the errors shown are the errors a save would hit.
# A save is all-or-nothing: any row error and nothing is written.
class Importer
  Row = Struct.new(:line, :data, :action, :errors, :note, keyword_init: true) do
    def ok? = errors.empty?
  end

  Result = Struct.new(:kind, :rows, :committed, keyword_init: true) do
    def errors? = rows.any? { !_1.ok? }
    def counts = rows.select(&:ok?).group_by(&:action).transform_values(&:size)
  end

  COLUMNS = {
    products: %w[sku name brand hsn gst_percent wholesale_price retail_price prices_include_gst warranty_months reorder_level opening_stock],
    customers: %w[name owner_name phone gstin address market price_tier credit_limit opening_balance],
    suppliers: %w[name brands gstin phone address credit_days opening_balance]
  }.freeze

  REQUIRED = {
    products: %w[sku name brand hsn wholesale_price retail_price],
    customers: %w[name market],
    suppliers: %w[name]
  }.freeze

  EXAMPLES = {
    products: [["PH-LED-9W", "LED Bulb 9W", "Philips", "8539", "18", "62", "99", "no", "12", "200", "600"]],
    customers: [["Gupta Electricals", "Rajesh Gupta", "9811000001", "06AABCG1234A1Z5", "12 Sadar Bazaar, Gurgaon 122001", "Sadar Bazaar", "wholesale", "50000", "12500"]],
    suppliers: [["Signify Distributor Gurgaon", "Philips", "06AAACS1234D1Z1", "9811999999", "Udyog Vihar Ph 4, Gurgaon", "30", "85000"]]
  }.freeze

  # Common ways people head their Excel columns.
  ALIASES = {
    "gst" => "gst_percent", "gst_rate" => "gst_percent", "tax" => "gst_percent", "gst_pct" => "gst_percent",
    "item" => "name", "item_name" => "name", "product" => "name", "product_name" => "name", "hsn_code" => "hsn",
    "wholesale" => "wholesale_price", "wholesale_rate" => "wholesale_price", "dealer_price" => "wholesale_price",
    "retail" => "retail_price", "mrp" => "retail_price", "retail_rate" => "retail_price",
    "incl_gst" => "prices_include_gst", "price_includes_gst" => "prices_include_gst",
    "warranty" => "warranty_months", "reorder" => "reorder_level", "min_stock" => "reorder_level",
    "stock" => "opening_stock", "qty" => "opening_stock", "opening_qty" => "opening_stock",
    "shop" => "name", "shop_name" => "name", "customer" => "name", "customer_name" => "name", "owner" => "owner_name",
    "mobile" => "phone", "phone_number" => "phone", "whatsapp" => "phone", "area" => "market",
    "tier" => "price_tier", "limit" => "credit_limit", "balance" => "opening_balance", "due" => "opening_balance",
    "outstanding" => "opening_balance", "shop_address" => "address", "addr" => "address", "supplier" => "name", "distributor" => "name", "brand_list" => "brands"
  }.freeze

  def self.template_csv(kind)
    CSV.generate { |csv| csv << COLUMNS.fetch(kind); EXAMPLES.fetch(kind).each { csv << _1 } }
  end

  def initialize(kind, path, user:)
    @kind = kind.to_sym
    raise ArgumentError, "unknown import #{kind}" unless COLUMNS.key?(@kind)
    @path, @user = path, user
  end

  def run(commit:)
    rows = read_rows
    ApplicationRecord.transaction do
      rows.each { |r| import_row(r) }
      raise ActiveRecord::Rollback if !commit || rows.any? { !_1.ok? }
    end
    Result.new(kind: @kind, rows: rows, committed: commit && rows.all?(&:ok?))
  end

  # ------------------------------------------------------------ reading
  def read_rows
    sheet = spreadsheet
    raw = sheet.row(1).map { normalise_header(_1) }
    header = raw.map { |h| COLUMNS[@kind].include?(h) ? h : ALIASES.fetch(h, h) }
    missing = REQUIRED[@kind] - header
    raise Books::Error, "Missing columns: #{missing.join(', ')}. Download the template to see the layout." if missing.any?
    unknown = header.reject { |h| h.empty? || COLUMNS[@kind].include?(h) }
    if unknown.any?
      raise Books::Error, "Column(s) not understood: #{unknown.join(', ')}. Rename them to match the template " \
                          "(#{COLUMNS[@kind].join(', ')}) or delete them."
    end

    (2..sheet.last_row.to_i).filter_map do |i|
      values = sheet.row(i).map { cell(_1) }
      next if values.all?(&:empty?)
      Row.new(line: i, data: header.zip(values).to_h.slice(*COLUMNS[@kind]), errors: [], action: nil)
    end.tap { raise Books::Error, "The sheet has no data rows" if _1.empty? }
  end

  private

  def spreadsheet
    ext = File.extname(@path).delete(".").downcase
    raise Books::Error, "Upload an Excel (.xlsx) or CSV file" unless %w[xlsx csv].include?(ext)
    Roo::Spreadsheet.open(@path, extension: ext.to_sym)
  rescue Zip::Error, ArgumentError, CSV::MalformedCSVError => e
    raise Books::Error, "Couldn't read that file (#{e.message.truncate(80)})"
  end

  def normalise_header(h) = h.to_s.strip.downcase.gsub(/[^a-z0-9]+/, "_").delete_suffix("_")

  # Excel gives numbers as floats (9811000001.0, 8539.0): turn whole numbers back into plain text.
  def cell(v)
    case v
    when nil then ""
    when Float then v == v.floor ? v.to_i.to_s : v.to_s
    else v.to_s.strip
    end
  end

  # ------------------------------------------------------------ rows
  def import_row(row)
    send(:"import_#{@kind}", row, row.data)
  rescue Books::Error, ActiveRecord::RecordInvalid, ArgumentError => e
    row.errors << clean_error(e)
  end

  def clean_error(e)
    e.respond_to?(:record) && e.record ? e.record.errors.full_messages.to_sentence : e.message
  end

  def money(v, field, row, allow_negative: false)
    return 0 if v.blank?
    s = v.delete(",").delete("₹").strip
    unless s.match?(/\A-?\d+(\.\d{1,2})?\z/)
      row.errors << "#{field.tr('_', ' ')} '#{v}' is not an amount"
      return 0
    end
    p = Shop::Money.paise(s)
    row.errors << "#{field.tr('_', ' ')} can't be negative" if p.negative? && !allow_negative
    p
  end

  def int(v, field, row)
    return 0 if v.blank?
    return v.to_i if v.match?(/\A\d+\z/)
    row.errors << "#{field.tr('_', ' ')} '#{v}' must be a whole number"
    0
  end

  def yes?(v) = %w[yes y true 1 incl inclusive].include?(v.to_s.downcase)

  def import_products(row, d)
    REQUIRED[:products].each { |c| row.errors << "#{c} is blank" if d[c].blank? }
    gst = d["gst_percent"].presence || "18"
    row.errors << "GST % must be 0, 5, 12, 18 or 28" unless %w[0 5 12 18 28].include?(gst.delete("%").strip)
    return if row.errors.any?

    product = Product.find_or_initialize_by(sku: d["sku"].upcase)
    row.action = product.new_record? ? "new" : "update"
    product.assign_attributes(
      name: d["name"], brand: d["brand"], hsn: d["hsn"], gst_bp: gst.delete("%").strip.to_i * 100,
      wholesale_price_paise: money(d["wholesale_price"], "wholesale_price", row),
      retail_price_paise: money(d["retail_price"], "retail_price", row),
      price_includes_tax: yes?(d["prices_include_gst"]),
      warranty_months: int(d["warranty_months"], "warranty_months", row),
      reorder_level: int(d["reorder_level"], "reorder_level", row))
    opening = int(d["opening_stock"], "opening_stock", row)
    return if row.errors.any?

    product.save!
    if opening.positive?
      if product.stock_movements.exists?
        row.note = "opening stock ignored: this product already has stock entries (use a physical count instead)"
      else
        Books.opening_stock(product, opening, user: @user)
      end
    end
  end

  def import_customers(row, d)
    REQUIRED[:customers].each { |c| row.errors << "#{c} is blank" if d[c].blank? }
    phone = d["phone"].to_s.gsub(/\D/, "").delete_prefix("91").last(10)
    phone = d["phone"].to_s.gsub(/\D/, "") if phone.size != 10 && d["phone"].present?
    tier = d["price_tier"].presence&.downcase || "wholesale"
    row.errors << "price tier must be wholesale or retail" unless %w[wholesale retail].include?(tier)
    return if row.errors.any?

    market = Market.find_by("LOWER(name) = ?", d["market"].downcase) || Market.create!(name: d["market"].strip)
    customer = (phone.present? && Customer.find_by(phone: phone)) || Customer.find_or_initialize_by(name: d["name"])
    row.action = customer.new_record? ? "new" : "update"
    row.note = "new market: #{market.name}" if market.previously_new_record?
    customer.assign_attributes(name: d["name"], owner_name: d["owner_name"].presence, phone: phone.presence,
                               gstin: d["gstin"].to_s.upcase.presence, market: market, price_tier: tier,
                               address: d["address"].presence || customer.address,
                               credit_limit_paise: money(d["credit_limit"], "credit_limit", row))
    opening = money(d["opening_balance"], "opening_balance", row, allow_negative: true)
    return if row.errors.any?

    customer.save!
    unless opening.zero?
      if customer.ledger_entries.exists?
        row.note = [row.note, "opening balance ignored: customer already has entries"].compact.join("; ")
      else
        Books.opening_balance(customer, opening, user: @user)
      end
    end
  end

  def import_suppliers(row, d)
    row.errors << "name is blank" if d["name"].blank?
    return if row.errors.any?

    supplier = Supplier.find_or_initialize_by(name: d["name"])
    row.action = supplier.new_record? ? "new" : "update"
    supplier.assign_attributes(brands: d["brands"].to_s, gstin: d["gstin"].presence, phone: d["phone"].presence,
                               address: d["address"].presence || supplier.address,
                               credit_days: d["credit_days"].present? ? int(d["credit_days"], "credit_days", row) : supplier.credit_days)
    opening = money(d["opening_balance"], "opening_balance", row, allow_negative: true)
    return if row.errors.any?

    supplier.save!
    unless opening.zero?
      if supplier.entries.exists?
        row.note = "opening balance ignored: supplier already has entries"
      else
        Books.supplier_opening(supplier, opening, user: @user)
      end
    end
  end
end
