require "csv"

class ReportsController < ApplicationController
  require_permission :reports
  before_action :set_range

  def index; end

  def sales
    inv = Invoice.posted.where(invoice_date: @from..@to)
    @by_market = inv.joins(customer: :market).group("markets.name").sum(:total_paise).sort_by { -_2 }
    @by_salesman = inv.joins(customer: { market: :salesman }).group("users.name").sum(:total_paise).sort_by { -_2 }
    @by_channel = inv.group(:channel).sum(:total_paise)
    lines = InvoiceLine.joins(:invoice, product: :brand).merge(inv)
    @by_brand = lines.group("brands.name").sum(:taxable_paise).sort_by { -_2 }
    @top_products = lines.group("products.id", "brands.name", "products.name").pluck(Arel.sql("brands.name || ' ' || products.name"), Arel.sql("SUM(invoice_lines.quantity)"), Arel.sql("SUM(invoice_lines.taxable_paise)"))
                         .sort_by { -_3 }.first(15)
    @margin = lines.sum("invoice_lines.taxable_paise - products.purchase_paise * invoice_lines.quantity") if can?(:margins)
    @total = inv.sum(:total_paise)
    @taxable = inv.sum(:taxable_paise)
    respond_to do |f|
      f.html
      f.csv { send_data csv_rows([["Market", "Sales"]] + @by_market.map { [_1, money(_2)] }), filename: "sales-by-market-#{@from}.csv" }
    end
  end

  def dues
    open = Invoice.posted.includes(:payment_allocations, :credit_notes, customer: :market).to_a.select(&:unpaid?)
    open.select!(&:overdue?) if params[:overdue] == "1"
    @rows = open.group_by(&:customer).map do |c, invs|
      ages = { "0–30" => 0, "31–60" => 0, "61–90" => 0, "90+" => 0 }
      invs.each do |i|
        days = (Date.current - i.invoice_date).to_i
        ages[days <= 30 ? "0–30" : days <= 60 ? "31–60" : days <= 90 ? "61–90" : "90+"] += i.outstanding_paise
      end
      { customer: c, total: invs.sum(&:outstanding_paise), overdue: invs.select(&:overdue?).sum(&:outstanding_paise), ages: ages,
        oldest: invs.map(&:invoice_date).min }
    end.sort_by { -_1[:total] }
    @rows.select! { _1[:customer].market_id.to_s == params[:market_id] } if params[:market_id].present?
    respond_to do |f|
      f.html
      f.csv do
        send_data csv_rows([["Customer", "Market", "Outstanding", "Overdue", "0-30", "31-60", "61-90", "90+"]] +
                           @rows.map { |r| [r[:customer].shop_name, r[:customer].market&.name, money(r[:total]), money(r[:overdue]), *r[:ages].values.map { money(_1) }] }),
                  filename: "dues-#{Date.current}.csv"
      end
    end
  end

  def collections
    pays = Payment.cleared.where(received_on: @from..@to).includes(:collected_by, customer: :market)
    @by_person = pays.group_by(&:collected_by).map { |u, ps| [u&.name || "—", ps.group_by(&:mode).transform_values { _1.sum(&:amount_paise) }, ps.sum(&:amount_paise)] }.sort_by { -_3 }
    @by_market = pays.group_by { _1.customer.market&.name || "No market" }.transform_values { _1.sum(&:amount_paise) }.sort_by { -_2 }
    @by_day = pays.group_by(&:received_on).transform_values { _1.sum(&:amount_paise) }.sort
    @total = pays.sum(&:amount_paise)
  end

  def gstr1
    @r = Reports::Gstr1.new(@month)
    respond_to do |f|
      f.html
      f.csv { send_data @r.csv(params[:table].presence_in(Reports::Gstr1::TABLES) || "b2b"), filename: "GSTR1-#{params[:table]}-#{@r.period}.csv" }
      f.json { send_data @r.to_json, filename: "GSTR1-#{@r.period}.json" }
    end
  end

  def gstr3b
    @r = Reports::Gstr3b.new(@month)
  end

  def hsn
    @r = Reports::Gstr1.new(@month)
  end

  def tally
    authorize!(:exports)
    send_data Reports::Tally.new(@from, @to).to_xml, filename: "tally-#{@from}-to-#{@to}.xml", type: "application/xml"
  end

  # Everything the CA asks for at month end, in one zip.
  def ca_pack
    authorize!(:exports)
    g1 = Reports::Gstr1.new(@month)
    buf = Zip::OutputStream.write_buffer do |z|
      Reports::Gstr1::TABLES.each { |t| z.put_next_entry("GSTR1/#{t}.csv"); z.write g1.csv(t) }
      z.put_next_entry("GSTR1/gstr1.json"); z.write g1.to_json
      z.put_next_entry("tally-vouchers.xml"); z.write Reports::Tally.new(g1.from, g1.to).to_xml
      z.put_next_entry("sales-register.csv")
      z.write csv_rows([["Invoice", "Date", "Customer", "GSTIN", "POS", "Taxable", "CGST", "SGST", "IGST", "Round off", "Total", "Status"]] +
                       Invoice.where(invoice_date: g1.from..g1.to).order(:number).map { |i| [i.number, i.invoice_date, i.bill_to_name, i.bill_to_gstin, i.place_of_supply, money(i.taxable_paise), money(i.cgst_paise), money(i.sgst_paise), money(i.igst_paise), money(i.round_off_paise), money(i.total_paise), i.status] })
      z.put_next_entry("credit-notes.csv")
      z.write csv_rows([["Number", "Date", "Invoice", "Reason", "Taxable", "Tax", "Total"]] +
                       ::CreditNote.where(note_date: g1.from..g1.to).includes(:invoice).map { |n| [n.number, n.note_date, n.invoice.number, n.reason_label, money(n.taxable_paise), money(n.tax_paise), money(n.total_paise)] })
      z.put_next_entry("receipts.csv")
      z.write csv_rows([["Receipt", "Date", "Customer", "Mode", "Reference", "Amount", "Status"]] +
                       Payment.where(received_on: g1.from..g1.to).includes(:customer).map { |p| [p.number, p.received_on, p.customer.shop_name, p.mode_label, p.reference, money(p.amount_paise), p.status] })
      z.put_next_entry("purchases.csv")
      z.write csv_rows([["Supplier", "GSTIN", "Bill", "Date", "Taxable", "GST", "Total"]] +
                       Purchase.where(bill_date: g1.from..g1.to).includes(:supplier).map { |p| [p.supplier.name, p.supplier.gstin, p.bill_no, p.bill_date, money(p.taxable_paise), money(p.tax_paise), money(p.total_paise)] })
      z.put_next_entry("stock-adjustments.csv")
      z.write csv_rows([["Date", "Product", "Bucket", "Reason", "Qty", "Note", "By"]] +
                       StockMovement.where(reason: %w[count_adjustment write_off], created_at: g1.from.beginning_of_day..g1.to.end_of_day).includes(:product, :user).map { |m| [m.created_at.to_date, m.product.label, m.bucket, m.reason, m.quantity, m.note, m.user&.name] })
    end
    send_data buf.string, filename: "CA-pack-#{@month.strftime('%Y-%m')}.zip", type: "application/zip"
  end

  def day_book
    @date = date_param(params[:date])
    @entries = LedgerEntry.where(entry_date: @date).includes(:party, :user, :document).order(:id)
    @movements = StockMovement.where(created_at: @date.all_day).includes(:product, :user).order(:id)
  end

  private

  def set_range
    @month = params[:month].present? ? Date.strptime(params[:month], "%Y-%m") : Date.current.prev_month.beginning_of_month
    @month = Date.current.beginning_of_month if params[:month].blank? && action_name.in?(%w[sales collections])
    @from = params[:from].present? ? date_param(params[:from]) : (action_name.in?(%w[gstr1 gstr3b hsn ca_pack tally]) ? @month : Date.current.beginning_of_month)
    @to = params[:to].present? ? date_param(params[:to]) : (action_name.in?(%w[gstr1 gstr3b hsn ca_pack tally]) ? @month.end_of_month : Date.current)
  rescue Date::Error
    @month = Date.current.beginning_of_month
    @from, @to = @month, Date.current
  end

  def money(p) = format("%.2f", p.to_i / 100.0)
  def csv_rows(rows) = CSV.generate { |c| rows.each { c << _1 } }
end
