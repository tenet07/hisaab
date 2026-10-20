require "rqrcode"

# GST tax invoice (rule 46): serial per FY, GSTINs, place of supply, HSN, rate-wise tax, amount in words.
class InvoicePdf < BasePdf
  def initialize(invoice, copy: "ORIGINAL FOR RECIPIENT")
    super()
    @inv = invoice
    @copy = copy
    render_doc
  end

  def render_doc
    inv = @inv
    letterhead(inv.b2b? ? "TAX INVOICE" : "TAX INVOICE (B2C)", @copy)
    text "CANCELLED — #{inv.cancel_reason}", size: 12, style: :bold, color: "DC2626" if inv.cancelled?
    two_col(-> {
      text "Bill to", color: MUTED
      text inv.bill_to_name, style: :bold, size: 10
      text inv.bill_to_address.to_s
      text "GSTIN #{inv.bill_to_gstin}" if inv.bill_to_gstin.present?
      text "Place of supply: #{GstStates::NAMES[inv.place_of_supply]} (#{inv.place_of_supply})"
    }, -> {
      kv "Invoice no.", inv.number
      kv "Date", inv.invoice_date.strftime("%d %b %Y")
      kv "Due", inv.due_date.strftime("%d %b %Y")
      kv "Customer code", inv.customer.code
      kv "E-way bill", inv.eway_bill_no.presence || "Required — not yet generated" if inv.eway_required
      kv "IRN", inv.irn if inv.irn.present?
      kv "Order", inv.order.number if inv.order
    })
    move_down 12

    igst = inv.igst_paise.positive?
    head = ["#", "Item", "HSN", "Qty", "Rate", "Disc %", "Taxable", "GST %", igst ? "IGST" : "CGST", (igst ? nil : "SGST"), "Amount"].compact
    rows = inv.lines.each_with_index.map do |l, i|
      [i + 1, l.description, l.hsn, l.quantity, money(l.rate_paise), (l.discount_pct.to_f.positive? ? l.discount_pct.to_f : ""),
       money(l.taxable_paise), "#{l.gst_rate.to_f}%", money(igst ? l.igst_paise : l.cgst_paise), (igst ? nil : money(l.sgst_paise)),
       money(l.total_paise)].compact
    end
    t = make_table([head] + rows, width: bounds.width, header: true, column_widths: { 1 => 150 })
    table_style(t, num_cols: (3...head.size).to_a)
    t.draw
    move_down 8

    top = cursor
    bounding_box([0, top], width: bounds.width * 0.55) do
      text "HSN summary", style: :bold
      hs = [["HSN", "Taxable", "Rate", igst ? "IGST" : "CGST + SGST"]] + inv.hsn_summary.map do |h|
        [h[:hsn], money(h[:taxable]), "#{h[:rate].to_f}%", money(h[:cgst] + h[:sgst] + h[:igst])]
      end
      ht = make_table(hs, width: bounds.width)
      table_style(ht, num_cols: [1, 2, 3])
      ht.draw
      move_down 8
      text "Amount in words", color: MUTED
      text Money.in_words(inv.total_paise), style: :bold
      if @shop.bank_details.present?
        move_down 6
        text "Bank: #{@shop.bank_details}", color: MUTED
      end
    end
    left_bottom = cursor
    bounding_box([bounds.width * 0.6, top], width: bounds.width * 0.4) do
      totals = [["Taxable value", money(inv.taxable_paise)]]
      if igst then totals << ["IGST", money(inv.igst_paise)]
      else totals += [["CGST", money(inv.cgst_paise)], ["SGST", money(inv.sgst_paise)]]
      end
      totals << ["Round off", money(inv.round_off_paise)] unless inv.round_off_paise.zero?
      totals << ["Total", money(inv.total_paise, symbol: true)]
      tt = make_table(totals, width: bounds.width)
      tt.cells.borders = []
      tt.cells.padding = [3, 4]
      tt.column(1).align = :right
      tt.row(-1).font_style = :bold
      tt.row(-1).size = 11
      tt.row(-1).borders = [:top]
      tt.row(-1).border_color = INK
      tt.draw
      if (uri = inv.upi_uri)
        move_down 8
        qr = RQRCode::QRCode.new(uri)
        png = qr.as_png(size: 240, border_modules: 1)
        image StringIO.new(png.to_s), width: 78, position: :right
        text "Scan to pay #{money(inv.outstanding_paise, symbol: true)} by UPI", align: :right, size: 7, color: MUTED
      end
    end
    move_cursor_to [cursor, left_bottom].min
    move_down 24
    text "For #{@shop.legal_name.presence || @shop.name}", align: :right
    move_down 22
    text "Authorised signatory", align: :right, color: MUTED
    footer_note "Goods once sold are replaced only under the brand's warranty, against this invoice. Subject to local jurisdiction."
  end
end
