require "test_helper"

class SettingsScreensTest < ActionDispatch::IntegrationTest
  test "first run asks for the shop, then settings; only owner can change them" do
    get new_setup_path
    assert_response :success
    post setup_path, params: { shop: { name: "Jain Lights", gstin: "23AABCJ1234A1Z5", state_code: "06" }, user: { name: "Amit", password: "2580" } }
    assert_redirected_to edit_settings_path
    assert_equal "Jain Lights", ShopSetting.current.name
    assert_equal "23", ShopSetting.current.state_code, "GSTIN wins over the picked state"

    patch settings_path, params: { shop_setting: { invoice_prefix: "JL", upi_id: "jain@okicici", tally_ledgers: { sales: "Sales A/c" } } }
    assert_redirected_to edit_settings_path
    assert_equal "Sales A/c", ShopSetting.first.ledgers[:sales]
    patch settings_path, params: { shop_setting: { invoice_prefix: "TOOLONG" } }
    assert_response :unprocessable_entity

    clerk = User.create!(name: "C", role: "accounts", password: "2580")
    delete session_path
    post session_path, params: { user_id: clerk.id, pin: "2580" }
    get edit_settings_path
    assert_redirected_to root_path
  end

  test "bad setup saves nothing" do
    post setup_path, params: { shop: { name: "X", gstin: "bad" }, user: { name: "Amit", password: "2580" } }
    assert_response :unprocessable_entity
    assert_equal 0, User.count
  end
end
