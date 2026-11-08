ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: 1)

    def setup_shop
      @owner = User.create!(name: "O", role: "owner", password: "1234")
      @acct = User.create!(name: "A", role: "accounts", password: "1234")
      @sales = User.create!(name: "S", role: "salesman", password: "1234")
      @market = Market.create!(name: "Sadar", delivery_day: "Mon", salesman: @sales)
      @shop = Customer.create!(name: "Gupta", phone: "9811000001", market: @market, price_tier: "wholesale")
      @far = Customer.create!(name: "Delhi Co", gstin: "07AADCD9999C1Z9", market: @market)
      @bulb = Product.create!(sku: "B9", name: "Bulb 9W", brand: "Philips", hsn: "8539", gst_bp: 1800,
                              retail_price_paise: 9_900, wholesale_price_paise: 6_200, warranty_months: 12)
      Books.opening_stock(@bulb, 100, user: @acct)
    end
  end
end

class ActiveSupport::TestCase
  def setup_delivery
    @driver = User.create!(name: "D", role: "delivery", password: "1234")
    @market.update!(delivery_person: @driver, delivery_day: Date::ABBR_DAYNAMES[Date.current.wday])
    @inv = Books.create_invoice(customer: @shop, user: @acct, items: [{ product: @bulb, qty: 10 }])
    @del = @inv.delivery
    @item = @del.items.first
  end
end
