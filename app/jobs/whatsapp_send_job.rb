class WhatsappSendJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  def perform(message_id)
    msg = WhatsappMessage.find(message_id)
    return unless msg.status == "queued"
    provider = Whatsapp::Provider.for
    res = provider.deliver(msg)
    if res.ok
      msg.update!(status: "sent", provider_message_id: res.id, error: nil)
    else
      msg.update!(status: "failed", error: res.error)
    end
  end
end
