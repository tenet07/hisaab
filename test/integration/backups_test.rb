require "test_helper"

class BackupsTest < ActionDispatch::IntegrationTest
  setup do
    @dir = Pathname(Dir.mktmpdir)
    ENV["BACKUP_DIR"] = @dir.to_s
    @owner = User.create!(name: "B Owner", role: "owner", password: "2580")
    @staff = User.create!(name: "B Accounts", role: "accounts", password: "2580")
    @dir.join("shopos-2026-11-08_2330.dump").write("PGDMP fake")
    @dir.join("notes.txt").write("not a backup")
  end
  teardown { ENV.delete("BACKUP_DIR"); FileUtils.rm_rf(@dir) }

  test "owner sees and downloads backups; nothing else in the folder is reachable" do
    post session_path, params: { user_id: @owner.id, pin: "2580" }
    get backups_path
    assert_response :success
    assert_match "shopos-2026-11-08_2330.dump", response.body
    assert_no_match "notes.txt", response.body
    get backup_path("shopos-2026-11-08_2330.dump")
    assert_response :success
    assert_equal "PGDMP fake", response.body
    get backup_path("notes.txt")
    assert_response :not_found
    get "/backups/..%2F..%2Fconfig%2Fmaster.key"
    assert_response :not_found
  end

  test "staff can't download backups" do
    post session_path, params: { user_id: @staff.id, pin: "2580" }
    get backup_path("shopos-2026-11-08_2330.dump")
    assert_redirected_to root_path
  end
end
