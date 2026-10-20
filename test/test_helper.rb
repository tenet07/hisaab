ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: 1)

    # A small shop built through the same services the app uses
    def build_shop
      Current.reset
      ShopSetting.current.update!(state_code: "27", credit_days: 30, discount_approval_pct: 10, gstin: Gstin.with_checksum("27AAGCS1234F1Z"))
      @owner = User.create!(name: "Owner", email_address: "o@t.test", password: "secret123", role: "owner")
      Current.session = @owner.sessions.create!(user_agent: "test")
      Current.device = "test"
      @brand = Brand.create!(name: "Philips", warranty_months: 12)
      @supplier = Supplier.create!(name: "Philips Dist", brand: @brand, state_code: "27")
      @bulb = Product.create!(brand: @brand, sku: "B9", name: "Bulb 9W", wattage: "9W", hsn: "85395000", gst_rate: 12,
                              mrp: 120, wholesale: 60, retail: 100, purchase: 50, aliases: "9w bulb")
      @batten = Product.create!(brand: @brand, sku: "BT20", name: "Batten 20W", wattage: "20W", hsn: "94051000", gst_rate: 18,
                                mrp: 450, wholesale: 240, retail: 400, purchase: 200)
      Stock::PurchaseEntry.call(supplier: @supplier, bill_no: "P1", bill_date: Date.current - 60,
                                items: [{ product: @bulb, quantity: 500, rate_paise: 5000 }, { product: @batten, quantity: 100, rate_paise: 20000 }])
      @market = Market.create!(name: "Dadar", delivery_weekday: Date.current.wday)
      @cust = Customer.create!(shop_name: "Gala Electricals", phone: "9820012345", market: @market, gstin: Gstin.with_checksum("27AAACG1234A1Z"))
    end

    def bill(customer = @cust, items = [{ product: @bulb, quantity: 10 }], **kw)
      Invoicing::Post.call(customer: customer, items: items, **kw)
    end
  end
end
