class TallyController < ApplicationController
  before_action :require_owner_or_accounts!
  def index
    @from = Date.current.beginning_of_month
    @to = Date.current
  end

  # Cancelled bills are left out; they never reach Tally.
  def export
    from, to = Date.parse(params[:from]), Date.parse(params[:to])
    s = ShopSetting.current
    exporter = Shop::TallyExport.new(company: s.tally_company.presence || s.name, ledgers: s.ledgers)
    invoices = Invoice.posted.where(date: from..to).includes(:customer, lines: :product).order(:number)
                      .map { |i| [i.to_core, i.customer.name] }
    receipts = Payment.where(date: from..to).includes(:customer).order(:date, :id).map do |p|
      { date: p.date, ref: p.ref, party: p.customer.name, amount: p.amount_paise, mode: p.mode.to_sym }
    end
    credit_notes = CreditNote.where(date: from..to).includes(:customer).order(:number).map do |c|
      { date: c.date, number: c.number, party: c.customer.name, taxable: c.taxable_paise,
        cgst: c.cgst_paise, sgst: c.sgst_paise, igst: c.igst_paise, total: c.total_paise }
    end
    purchases = PurchaseBill.where(date: from..to).includes(:supplier, lines: :product).order(:date, :id)
                            .map { |b| [b.to_core, b.supplier.name] }
    payments = SupplierPayment.where(date: from..to).includes(:supplier).order(:date, :id).map do |p|
      { date: p.date, ref: p.ref, party: p.supplier.name, amount: p.amount_paise, mode: p.mode.to_sym }
    end
    claim_credits = ClaimCredit.where(date: from..to).includes(:supplier).order(:date, :id).map do |c|
      { date: c.date, number: c.number, party: c.supplier.name, amount: c.amount_paise }
    end
    send_data exporter.to_xml(invoices: invoices, receipts: receipts, credit_notes: credit_notes,
                              purchases: purchases, payments: payments, claim_credits: claim_credits),
              filename: "tally-#{from}-to-#{to}.xml", type: "application/xml"
  end
end
