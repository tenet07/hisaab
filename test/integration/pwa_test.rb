require "test_helper"

class PwaTest < ActionDispatch::IntegrationTest
  test "manifest and service worker are public and name the shop" do
    ShopSetting.current.update!(name: "Solanki Electricals")
    get "/manifest.json"
    assert_response :success
    m = JSON.parse(response.body)
    assert_equal "Solanki Electricals", m["name"]
    assert_equal "standalone", m["display"]
    assert m["icons"].any? { _1["purpose"] == "maskable" }
    get "/service-worker.js"
    assert_response :success
    assert_match "offline.html", response.body
  end
end
