# Customer ledger statement for a period: opening balance, every entry, running balance, open bills.
class StatementPdf < BasePdf
  def initialize(customer, from:, to:)
    super()
    letterhead("STATEMENT OF ACCOUNT", "#{from.strftime('%d %b %Y')} – #{to.strftime('%d %b %Y')}")
    text customer.shop_name, style: :bold, size: 10
    text [customer.owner_name, customer.display_phone, customer.gstin && "GSTIN #{customer.gstin}"].compact.join(" · "), color: MUTED
    move_down 10
    bal = customer.balance_on(from - 1)
    rows = [["Date", "Particulars", "Debit", "Credit", "Balance"], ["", "Opening balance", "", "", fmt(bal)]]
    customer.ledger_entries.where(entry_date: from..to).chronological.each do |e|
      bal += e.debit_paise - e.credit_paise
      rows << [e.entry_date.strftime("%d %b"), e.narration, (money(e.debit_paise) if e.debit_paise.positive?),
               (money(e.credit_paise) if e.credit_paise.positive?), fmt(bal)]
    end
    rows << ["", "Closing balance", "", "", fmt(bal)]
    t = make_table(rows, width: bounds.width, header: true, column_widths: { 1 => 230 })
    table_style(t, num_cols: [2, 3, 4])
    t.row(-1).font_style = :bold
    t.draw
    open = customer.open_items
    if open.any?
      move_down 14
      text "Unpaid bills", style: :bold
      ot = make_table([["Invoice", "Date", "Due", "Days late", "Outstanding"]] + open.map do |i|
        [i.number, i.invoice_date.strftime("%d %b %Y"), i.due_date.strftime("%d %b %Y"), i.days_overdue.positive? ? i.days_overdue : "", money(i.outstanding_paise)]
      end, width: bounds.width)
      table_style(ot, num_cols: [3, 4])
      ot.draw
    end
    footer_note "Please report any difference within 7 days."
  end

  def fmt(p) = p.negative? ? "#{money(-p)} Cr" : "#{money(p)} Dr"
end
