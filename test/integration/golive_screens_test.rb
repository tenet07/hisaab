require "test_helper"

class GoLiveScreensTest < ActionDispatch::IntegrationTest
  test "empty install asks for the owner, then owner manages staff" do
    get new_session_path
    assert_redirected_to new_setup_path
    post setup_path, params: { user: { name: "Gunjan", password: "12" } }
    assert_response :unprocessable_entity
    post setup_path, params: { shop: { name: "Solanki Electricals" }, user: { name: "Gunjan", password: "2580" } }
    assert_redirected_to edit_settings_path
    get new_setup_path
    assert_redirected_to new_session_path, "setup can't be run twice"

    post users_path, params: { user: { name: "Ravi", role: "delivery", password: "4455" } }
    ravi = User.find_by!(name: "Ravi")
    owner = User.find_by!(name: "Gunjan")
    patch user_path(owner), params: { user: { active: "0" } }
    assert owner.reload.active, "owner can't lock themselves out"
    patch user_path(ravi), params: { user: { active: "0", password: "" } }
    refute ravi.reload.active
    assert ravi.authenticate("4455"), "blank PIN keeps the old one"
  end

  test "change own PIN and import via upload with preview" do
    owner = User.create!(name: "O", role: "owner", password: "1234")
    post session_path, params: { user_id: owner.id, pin: "1234" }
    patch pin_path, params: { current_pin: "9999", pin: "2580", pin_confirmation: "2580" }
    assert owner.reload.authenticate("1234")
    patch pin_path, params: { current_pin: "1234", pin: "2580", pin_confirmation: "2580" }
    assert owner.reload.authenticate("2580")

    get template_imports_path(kind: "products")
    assert_includes response.body, "sku,name,brand"
    post imports_path, params: { kind: "products", file: fixture_file_upload("products.xlsx") }
    assert_response :success
    assert_includes response.body, "Save 2 rows"
    assert_equal 0, Product.count
    post commit_imports_path
    assert_redirected_to imports_path
    assert_equal 2, Product.count

    post imports_path, params: { kind: "products", file: fixture_file_upload("products_bad.xlsx") }
    assert_includes response.body, "Fix and upload again"
    refute_includes response.body, "Save 3 rows"
  end

  test "non-owners can't manage staff; delivery can change own PIN" do
    d = User.create!(name: "D", role: "delivery", password: "1234")
    post session_path, params: { user_id: d.id, pin: "1234" }
    get users_path
    assert_redirected_to run_deliveries_path
    get edit_pin_path
    assert_response :success
  end
end
