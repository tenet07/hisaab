class EinvoiceJob < ApplicationJob
  retry_on StandardError, wait: :polynomially_longer, attempts: 6
  def perform(invoice_id) = Gst::Einvoice.generate!(Invoice.find(invoice_id))
end
