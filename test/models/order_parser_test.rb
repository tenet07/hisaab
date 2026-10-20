require "test_helper"

class OrderParserTest < ActiveSupport::TestCase
  setup { build_shop }

  test "fuzzy parser reads the plan's example and carries the brand forward" do
    lines = OrderParser::Fuzzy.parse("Philips 9W bulb 50 pc, 20W batten 10")
    assert_equal [[@bulb, 50], [@batten, 10]], lines.map { [_1.product, _1.quantity] }
  end

  test "Hinglish order becomes a draft with low-confidence lines flagged" do
    order = OrderParser.draft!(customer: @cust, text: "bhai 9w philips 50 pc aur kuch xyz 3 bhej do")
    assert order.draft?
    assert_equal 2, order.lines.size
    assert order.needs_review?
  end
end
