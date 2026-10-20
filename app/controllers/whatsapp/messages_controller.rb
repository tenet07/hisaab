module Whatsapp
  # A WhatsApp-Web-style inbox: conversations on the left, the thread on the right.
  class MessagesController < ApplicationController
    require_permission :whatsapp

    def index
      latest = WhatsappMessage.where.not(customer_id: nil).group(:customer_id).maximum(:id)
      @threads = WhatsappMessage.where(id: latest.values).includes(:customer).order(id: :desc).limit(60)
      @unknown = WhatsappMessage.inbound.where(customer_id: nil).recent.limit(10)
      @customer = Customer.find_by(id: params[:customer_id]) || @threads.first&.customer
      @messages = @customer ? @customer.whatsapp_messages.includes(:document).order(:id).last(80) : []
      @stats = { sent: WhatsappMessage.outbound.where(created_at: Date.current.beginning_of_month..).count,
                 cost: WhatsappMessage.outbound.where(created_at: Date.current.beginning_of_month..).sum(:cost_paise),
                 failed: WhatsappMessage.where(status: "failed", created_at: 7.days.ago..).count,
                 provider: Whatsapp::Provider.for.name }
    end

    def create
      require_writer!
      c = Customer.find(params.require(:customer_id))
      in_window = c.whatsapp_messages.inbound.where(created_at: 24.hours.ago..).exists?
      raise ArgumentError, "Free text can only be sent within 24 hours of the customer's last message. Use a template (send a bill, receipt or statement)." unless in_window
      WhatsappNotifier.text(c, params.require(:body))
      redirect_to whatsapp_messages_path(customer_id: c.id)
    end
  end
end
