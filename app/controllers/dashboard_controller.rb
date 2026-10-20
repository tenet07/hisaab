class DashboardController < ApplicationController
  def show
    return redirect_to(m_root_path) if Current.user.mobile_first?
    return redirect_to(counter_path) if Current.user.counter?

    today = Date.current
    @today_sales = Invoice.posted.where(invoice_date: today).sum(:total_paise)
    @today_bills = Invoice.posted.where(invoice_date: today).count
    @today_collections = Payment.cleared.where(received_on: today).sum(:amount_paise)
    @month_sales = Invoice.posted.where(invoice_date: today.beginning_of_month..today).sum(:total_paise)
    @outstanding = LedgerEntry.where(party_type: "Customer").sum("debit_paise - credit_paise")
    open_invoices = Receivables.open_items
    @overdue = open_invoices.select(&:overdue?).sum(&:outstanding_paise)

    @daily = (13.downto(0)).map { |i| today - i }.index_with(0)
                           .merge(Invoice.posted.where(invoice_date: (today - 13)..today).group(:invoice_date).sum(:total_paise))

    month = today.beginning_of_month..today
    sales = Invoice.posted.where(invoice_date: month).joins(:customer).group("customers.market_id").sum(:total_paise)
    coll = Payment.cleared.where(received_on: month).joins(:customer).group("customers.market_id").sum(:amount_paise)
    dues = open_invoices.group_by { _1.customer.market_id }
    @markets = (Market.all.to_a + [nil]).map do |m|
      mid = m&.id
      inv = dues[mid] || []
      { market: m, sales: sales[mid].to_i, collected: coll[mid].to_i, due: inv.sum(&:outstanding_paise),
        overdue: inv.select(&:overdue?).sum(&:outstanding_paise) }
    end.reject { |r| r[:market].nil? && r.except(:market).values.all?(&:zero?) }

    @stock_alerts = Product.below_reorder.first(8)
    @sync_rejects = AuditEvent.where(action: "sync_rejected", created_at: 3.days.ago..).includes(:user).recent.limit(5)
    @approvals = Approval.pending.includes(:subject, :requested_by).recent.limit(5)
    @flagged_claims = BrandClaim.unsettled.includes(:brand, :replacements).select(&:flagged?)
    @open_orders = Order.open.includes(:customer).recent.limit(6)
    @runs = DispatchRun.for_date(today).includes(:market, deliveries: :invoice)
    @top_overdue = open_invoices.select(&:overdue?).group_by(&:customer).map { |c, invs| [c, invs.sum(&:outstanding_paise), invs.map(&:days_overdue).max] }
                                .sort_by { -_2 }.first(6)
    @awaiting_claim = StockMovement.where(bucket: "awaiting_claim").sum(:quantity)
    @with_brand = StockMovement.where(bucket: "with_brand").sum(:quantity)
  end
end
