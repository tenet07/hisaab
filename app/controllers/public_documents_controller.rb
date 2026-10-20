# Signed, expiring links for PDFs sent on WhatsApp (the customer has no login).
class PublicDocumentsController < ApplicationController
  allow_unauthenticated_access

  def show
    record = GlobalID::Locator.locate_signed(params[:token], for: "public_doc")
    return head(:not_found) unless record
    pdf, name = case record
                when Invoice then [InvoicePdf.new(record), record.number]
                when CreditNote then [CreditNotePdf.new(record), record.number]
                when Customer
                  from = date_param(params[:from], Date.current.beginning_of_month)
                  [StatementPdf.new(record, from: from, to: date_param(params[:to])), "statement-#{record.code}"]
                else return head(:not_found)
                end
    send_data pdf.render, filename: "#{name.tr('/', '-')}.pdf", type: "application/pdf", disposition: "inline"
  end
end
