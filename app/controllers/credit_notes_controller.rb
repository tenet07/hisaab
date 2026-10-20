class CreditNotesController < ApplicationController
  require_permission :credit_notes, except: %i[new create]
  before_action :require_writer!, only: %i[new create]

  def index
    @credit_notes = CreditNote.includes(:customer, :invoice).recent.limit(200)
  end

  def show
    @cn = CreditNote.find(params[:id])
    respond_to do |f|
      f.html
      f.pdf { send_data CreditNotePdf.new(@cn).render, filename: "#{@cn.number.tr('/', '-')}.pdf", type: "application/pdf", disposition: "inline" }
    end
  end

  def new
    authorize!(:credit_notes)
    @invoice = Invoice.find(params[:invoice_id])
    @credited = @invoice.credited_qty_by_line
  end

  def create
    authorize!(:credit_notes)
    invoice = Invoice.find(params[:invoice_id])
    lines = invoice.lines.index_by(&:id)
    items = (params[:lines]&.to_unsafe_h || {}).filter_map do |id, r|
      line = lines[id.to_i]
      next unless line && r["quantity"].to_i.positive?
      { invoice_line: line, quantity: r["quantity"].to_i, rate_paise: (Money.to_paise(r["rate"]) if params[:reason] == "rate_difference") }
    end
    cn = Invoicing::CreditNote.call(invoice: invoice, reason: params[:reason], items: items,
                                    restock_bucket: params[:reason] == "rate_difference" ? nil : params[:restock_bucket], notes: params[:notes])
    WhatsappNotifier.credit_note(cn) if params[:whatsapp] == "1"
    redirect_to cn, notice: "Credit note #{cn.number} posted."
  end
end
