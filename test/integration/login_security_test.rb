require "test_helper"

class LoginSecurityTest < ActionDispatch::IntegrationTest
  setup { @u = User.create!(name: "Test Owner", role: "owner", password: "2580") }

  test "five wrong PINs lock the login, even the right PIN, until a new PIN is set" do
    4.times { post session_path, params: { user_id: @u.id, pin: "0000" } }
    assert_equal 4, @u.reload.failed_pins
    assert_match "1 try left", flash[:alert]
    post session_path, params: { user_id: @u.id, pin: "0000" }
    assert @u.reload.locked?
    assert_match "locked for 15 minutes", flash[:alert]

    post session_path, params: { user_id: @u.id, pin: "2580" }
    assert_match "locked", flash[:alert]
    assert_nil session[:user_id]

    @u.update!(password: "3691")
    refute @u.reload.locked?
    post session_path, params: { user_id: @u.id, pin: "3691" }
    assert_equal @u.id, session[:user_id]
  end

  test "lock expires after 15 minutes and a right PIN clears the count" do
    5.times { post session_path, params: { user_id: @u.id, pin: "0000" } }
    travel 16.minutes do
      post session_path, params: { user_id: @u.id, pin: "2580" }
      assert_equal @u.id, session[:user_id]
    end
  end

  test "a right PIN resets the wrong count" do
    3.times { post session_path, params: { user_id: @u.id, pin: "0000" } }
    post session_path, params: { user_id: @u.id, pin: "2580" }
    assert_equal 0, @u.reload.failed_pins
  end

  test "first-run setup needs the server's setup code when one is set" do
    User.delete_all
    ENV["SETUP_CODE"] = "river-lamp-42"
    post setup_path, params: { setup_code: "guess", shop: { name: "X", state_code: "06" }, user: { name: "Intruder", password: "2580" } }
    assert_response :unprocessable_entity
    assert_equal 0, User.count
    post setup_path, params: { setup_code: "river-lamp-42", shop: { name: "Real Shop", state_code: "06" }, user: { name: "Gunjan", password: "2580" } }
    assert_redirected_to edit_settings_path
    assert User.find_by(name: "Gunjan").owner?
  ensure
    ENV.delete("SETUP_CODE")
  end
end
