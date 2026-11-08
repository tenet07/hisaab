require "test_helper"

class ImporterTest < ActiveSupport::TestCase
  setup do
    @owner = User.create!(name: "O", role: "owner", password: "1234")
    Market.create!(name: "Sadar Bazaar")
  end
  def file(name) = file_fixture(name).to_s
  def run_import(kind, name, commit:) = Importer.new(kind, file(name), user: @owner).run(commit: commit)

  test "preview saves nothing; commit saves products with opening stock" do
    r = run_import(:products, "products.xlsx", commit: false)
    refute r.errors?
    assert_equal 2, r.rows.size, "blank rows are skipped"
    assert_equal 0, Product.count

    r = run_import(:products, "products.xlsx", commit: true)
    assert r.committed
    bulb = Product.find_by!(sku: "PH-LED-9W")
    assert_equal "8539", bulb.hsn, "Excel numbers come through as plain text"
    assert_equal 1800, bulb.gst_bp
    assert_equal 600, bulb.stock
    assert_equal 205_050, Product.find_by!(sku: "HV-FAN-1200").wholesale_price_paise
  end

  test "re-importing updates instead of duplicating and doesn't double stock" do
    run_import(:products, "products.xlsx", commit: true)
    r = run_import(:products, "products.xlsx", commit: true)
    assert_equal({ "update" => 2 }, r.counts)
    assert_equal 2, Product.count
    assert_equal 600, Product.find_by!(sku: "PH-LED-9W").stock
    assert_match(/ignored/, r.rows.first.note)
  end

  test "one bad row blocks the whole save and every problem is reported" do
    r = run_import(:products, "products_bad.xlsx", commit: true)
    refute r.committed
    assert_equal 0, Product.count, "the good row is not saved either"
    msgs = r.rows.flat_map(&:errors).join(" ")
    assert_match(/GST %/, msgs)
    assert_match(/'abc' is not an amount/, msgs)
  end

  test "customers: phone cleaned, market matched or created, opening balances" do
    r = run_import(:customers, "customers.xlsx", commit: true)
    assert r.committed, r.rows.flat_map(&:errors).inspect
    g = Customer.find_by!(name: "Gupta Electricals")
    assert_equal "9811000001", g.phone
    assert_equal "06", g.state_code
    assert_equal 1_250_000, g.balance_paise
    assert_equal 5_000_000, g.credit_limit_paise
    s = Customer.find_by!(name: "Sharma Light House")
    assert_equal "9811000002", s.phone
    assert_equal "retail", s.price_tier
    assert_equal(-50_000, s.balance_paise, "negative opening = shop owes them")
    assert Market.exists?(name: "Naya Bazaar")
    assert_match(/new market/, r.rows.last.note)
  end

  test "unrecognised columns are refused instead of silently ignored" do
    csv = Rails.root.join("tmp/odd.csv"); File.write(csv, "sku,name,brand,hsn,wholesale,mrp,gst rate,colour\nA,B,C,1,1,2,12,red\n")
    e = assert_raises(Books::Error) { Importer.new(:products, csv.to_s, user: @owner).run(commit: false) }
    assert_match(/not understood: colour/, e.message)
    File.write(csv, "sku,name,brand,hsn,wholesale,mrp,gst rate\nA,B,C,1,1,2,12\n")
    Importer.new(:products, csv.to_s, user: @owner).run(commit: true)
    assert_equal 1200, Product.find_by!(sku: "A").gst_bp, "aliases: gst rate, wholesale, mrp"
  end

  test "missing required columns are explained" do
    csv = Rails.root.join("tmp/bad.csv"); File.write(csv, "name,phone\nX,1\n")
    e = assert_raises(Books::Error) { Importer.new(:customers, csv.to_s, user: @owner).run(commit: false) }
    assert_match(/Missing columns: market/, e.message)
  end

  test "templates round-trip through the importer" do
    Importer::COLUMNS.each_key do |kind|
      path = Rails.root.join("tmp/#{kind}-t.csv"); File.write(path, Importer.template_csv(kind))
      r = Importer.new(kind, path.to_s, user: @owner).run(commit: false)
      refute r.errors?, "#{kind}: #{r.rows.flat_map(&:errors)}"
    end
  end
end
