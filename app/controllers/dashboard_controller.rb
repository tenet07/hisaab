class DashboardController < ApplicationController
  def show
    today = Date.current
    @sales_today = Invoice.posted.where(date: today).sum(:total_paise)
    @bills_today = Invoice.posted.where(date: today).count
    @collected_today = Payment.where(date: today).group(:mode).sum(:amount_paise)
    @total_due = LedgerEntry.sum("debit_paise - credit_paise")
    @due_by_market = Market.order(:name).map do |m|
      [m, LedgerEntry.joins(:customer).where(customers: { market_id: m.id }).sum("debit_paise - credit_paise")]
    end
    @low_stock = Product.order(:brand, :name).select(&:low_stock?)
    @awaiting = Product.order(:brand).map { |p| [p, p.stock(:awaiting_claim)] }.select { |_, q| q.positive? }
                       .group_by { |p, _| p.brand }
    @with_brand = ClaimLine.joins(:claim).where.not(claims: { status: "closed" }).includes(:product, :claim)
                           .select { |l| l.open_qty.positive? }
    @over_limit = Customer.includes(:market).select(&:over_limit?)
    @owed_to_suppliers = SupplierEntry.sum("credit_paise - debit_paise")
    @supplier_due_now = Supplier.all.flat_map(&:unpaid_bills).select { |u| u[:due_on] <= today }.sum { |u| u[:due] }
    @claims_awaiting_credit = Claim.includes(:credits, lines: :product).select { |c| c.credit_qty.positive? && c.credits.empty? }
    # presentation only: today's dispatch at a glance
    @runs = Delivery.where("run_date <= ?", today).where(status: Delivery::OPEN)
    @unassigned = @runs.where(assigned_to_id: nil).count
    @failed = Delivery.where(status: "failed").count
  end
end
