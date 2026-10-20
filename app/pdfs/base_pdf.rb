require "prawn"
require "prawn/table"

# Shared letterhead and helpers for every printed document.
class BasePdf
  include Prawn::View
  FONT_DIR = Rails.root.join("vendor/fonts").to_s
  INK = "0F172A"
  MUTED = "64748B"
  LINE = "E2E8F0"
  BRAND = "3B55E6"

  def initialize
    @shop = ShopSetting.current
    setup_fonts
  end

  def document = @document ||= Prawn::Document.new(page_size: "A4", margin: [36, 36, 48, 36], info: { Creator: "Hisaab" })

  def setup_fonts
    # DejaVu has the ₹ glyph; Helvetica doesn't
    if File.exist?("#{FONT_DIR}/DejaVuSans.ttf")
      font_families.update("DejaVu" => { normal: "#{FONT_DIR}/DejaVuSans.ttf", bold: "#{FONT_DIR}/DejaVuSans-Bold.ttf" })
      font "DejaVu"
      @rupee = "₹"
    else
      @rupee = "Rs."
    end
    font_size 8.5
    default_leading 1
  end

  def money(paise, symbol: false) = Money.format(paise, symbol: false).then { symbol ? "#{@rupee}#{_1}" : _1 }

  def letterhead(title, subtitle = nil)
    bounding_box([0, cursor], width: bounds.width) do
      fill_color BRAND
      text @shop.legal_name.presence || @shop.name, size: 15, style: :bold
      fill_color INK
      text @shop.address.to_s, color: MUTED
      parts = [("GSTIN #{@shop.gstin}" if @shop.gstin.present?), ("State #{@shop.state_name} (#{@shop.state_code})"),
               ("Ph +#{@shop.phone}" if @shop.phone.present?), @shop.email.presence].compact
      text parts.join("  ·  "), color: MUTED
    end
    move_up 30
    text title, size: 13, style: :bold, align: :right
    text subtitle, align: :right, color: MUTED if subtitle
    move_down 10
    stroke_color LINE
    stroke_horizontal_rule
    move_down 10
  end

  def two_col(left, right)
    top = cursor
    bounding_box([0, top], width: bounds.width / 2 - 8) { left.call }
    h1 = top - cursor
    bounding_box([bounds.width / 2 + 8, top], width: bounds.width / 2 - 8) { right.call }
    h2 = top - cursor
    move_cursor_to top - [h1, h2].max
  end

  def kv(label, value)
    text "<color rgb='#{MUTED}'>#{label}</color>  #{value}", inline_format: true
  end

  def footer_note(note)
    number_pages "#{note}   Page <page> of <total>", at: [0, -20], width: bounds.width, size: 7, color: MUTED, align: :center
  end

  def table_style(t, num_cols: [])
    t.cells.borders = [:bottom]
    t.cells.border_color = LINE
    t.cells.padding = [4, 4]
    t.row(0).font_style = :bold
    t.row(0).background_color = "F8FAFC"
    num_cols.each { |c| t.column(c).align = :right }
  end
end
