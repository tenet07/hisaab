module Whatsapp
  # Meta Cloud API webhook: GET verifies the subscription, POST carries messages and delivery statuses.
  class WebhooksController < ApplicationController
    allow_unauthenticated_access only: %i[verify receive]
    skip_forgery_protection only: :receive

    def verify
      token = ENV["WHATSAPP_VERIFY_TOKEN"].presence || Rails.application.credentials.dig(:whatsapp, :verify_token)
      if token.present? && params["hub.mode"] == "subscribe" && ActiveSupport::SecurityUtils.secure_compare(params["hub.verify_token"].to_s, token)
        render plain: params["hub.challenge"]
      else
        head :forbidden
      end
    end

    def receive
      return head(:unauthorized) unless signature_ok?
      payload = JSON.parse(request.raw_post)
      Array(payload["entry"]).flat_map { Array(_1["changes"]) }.each do |change|
        value = change["value"] || {}
        Array(value["messages"]).each do |m|
          text = m.dig("text", "body") || m.dig("button", "text") || m.dig("interactive", "button_reply", "title")
          Whatsapp::Inbound.handle(phone: m["from"], text: text.to_s, provider_id: m["id"]) if text
        end
        Array(value["statuses"]).each do |s|
          WhatsappMessage.where(provider_message_id: s["id"]).update_all(status: s["status"], updated_at: Time.current)
        end
      end
      head :ok
    end

    # Owner/accounts can type as a customer to try the flow without a phone.
    def simulate
      authorize!(:whatsapp)
      c = Customer.find(params.require(:customer_id))
      Whatsapp::Inbound.handle(phone: c.phone, text: params.require(:body))
      redirect_to whatsapp_messages_path(customer_id: c.id), notice: "Simulated message from #{c.shop_name}."
    end

    private

    def signature_ok?
      secret = ENV["WHATSAPP_APP_SECRET"].presence || Rails.application.credentials.dig(:whatsapp, :app_secret)
      return Rails.env.local? if secret.blank?
      expected = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, request.raw_post)}"
      ActiveSupport::SecurityUtils.secure_compare(expected, request.headers["X-Hub-Signature-256"].to_s)
    end
  end
end
