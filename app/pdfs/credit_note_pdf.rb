class CreditNotePdf < BasePdf
  def initialize(cn)
    super()
    @cn = cn
    letterhead("CREDIT NOTE", "Against invoice #{cn.invoice.number} dated #{cn.invoice.invoice_date.strftime('%d %b %Y')}")
    two_col(-> {
      text "Issued to", color: MUTED
      text cn.invoice.bill_to_name, style: :bold, size: 10
      text "GSTIN #{cn.invoice.bill_to_gstin}" if cn.invoice.bill_to_gstin.present?
    }, -> {
      kv "Credit note no.", cn.number
      kv "Date", cn.note_date.strftime("%d %b %Y")
      kv "Reason", cn.reason_label
    })
    move_down 12
    rows = [["Item", "Qty", "Rate", "Taxable", "GST %", "Tax", "Amount"]] + cn.lines.map do |l|
      [l.product.display_name, l.quantity, money(l.rate_paise), money(l.taxable_paise), "#{l.gst_rate.to_f}%", money(l.tax_paise), money(l.total_paise)]
    end
    t = make_table(rows, width: bounds.width)
    table_style(t, num_cols: (1..6).to_a)
    t.draw
    move_down 10
    text "Total credit #{money(cn.total_paise, symbol: true)}", style: :bold, size: 11, align: :right
    text Money.in_words(cn.total_paise), align: :right, color: MUTED
    text "Note: #{cn.notes}" if cn.notes.present?
    footer_note "This credit has been applied to your account."
  end
end
