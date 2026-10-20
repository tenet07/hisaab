module Whatsapp
  # Sends through the WhatsApp Business Platform. "cloud" talks to Meta's Cloud API directly (BSPs
  # such as Gupshup/Interakt/AiSensy expose the same shape); "log" just records the message, for
  # development and for shops that haven't connected WhatsApp yet.
  module Provider
    Result = Struct.new(:ok, :id, :error, keyword_init: true)
    module_function

    def for(name = ShopSetting.current.whatsapp_provider)
      name == "cloud" && Cloud.configured? ? Cloud : Log
    end

    module Log
      module_function
      def deliver(_msg) = Result.new(ok: true, id: "log-#{SecureRandom.hex(6)}")
      def name = "log"
    end

    module Cloud
      GRAPH = "https://graph.facebook.com/v21.0".freeze
      module_function

      def creds = Rails.application.credentials.whatsapp || {}
      def token = ENV["WHATSAPP_TOKEN"].presence || creds[:token]
      def phone_number_id = ENV["WHATSAPP_PHONE_NUMBER_ID"].presence || creds[:phone_number_id]
      def configured? = token.present? && phone_number_id.present?
      def name = "cloud"

      def deliver(msg)
        body = { messaging_product: "whatsapp", to: msg.phone }
        if msg.template.present?
          params = Array(msg.payload["params"]).map { { type: "text", text: _1.to_s } }
          components = [{ type: "body", parameters: params }]
          if (doc = msg.payload["document_url"])
            components.unshift({ type: "header", parameters: [{ type: "document", document: { link: doc, filename: msg.payload["filename"] } }] })
          end
          body.merge!(type: "template", template: { name: msg.template, language: { code: msg.payload["lang"] || "en" }, components: components })
        else
          body.merge!(type: "text", text: { body: msg.body, preview_url: false })
        end
        uri = URI("#{GRAPH}/#{phone_number_id}/messages")
        res = Net::HTTP.post(uri, body.to_json, "Authorization" => "Bearer #{token}", "Content-Type" => "application/json")
        json = JSON.parse(res.body) rescue {}
        if res.is_a?(Net::HTTPSuccess)
          Result.new(ok: true, id: json.dig("messages", 0, "id"))
        else
          Result.new(ok: false, error: json.dig("error", "message") || "HTTP #{res.code}")
        end
      rescue StandardError => e
        Result.new(ok: false, error: e.message)
      end
    end
  end
end
