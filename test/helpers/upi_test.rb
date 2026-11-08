require "test_helper"

class UpiTest < ActionView::TestCase
  include ApplicationHelper
  test "UPI link has the exact amount and a literal @" do
    u = upi_uri("solanki.elec@okhdfcbank", "Solanki & Sons", 1_073_800, "SE/26-27/00001")
    assert_equal "upi://pay?pa=solanki.elec@okhdfcbank&pn=Solanki%20%26%20Sons&am=10738.00&cu=INR&tn=SE%2F26-27%2F00001", u
    assert_includes upi_qr_svg(u), "<svg"
  end
end
