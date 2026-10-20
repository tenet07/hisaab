module Whatsapp
  # Owner's market broadcasts: new stock, offers. Marketing template, opted-in customers only.
  class BroadcastsController < ApplicationController
    before_action { raise Forbidden unless Current.user.owner? }

    def index = @broadcasts = Broadcast.order(created_at: :desc)
    def new = @broadcast = Broadcast.new
    def show = @broadcast = Broadcast.find(params[:id])

    def create
      @broadcast = Broadcast.create!(params.require(:broadcast).permit(:title, :body, market_ids: []).merge(created_by: Current.user)
                                         .tap { _1[:market_ids] = Array(_1[:market_ids]).compact_blank.map(&:to_i) })
      redirect_to whatsapp_broadcast_path(@broadcast)
    end

    def deliver
      b = Broadcast.find(params[:id])
      raise ArgumentError, "Already sent" if b.sent?
      n = 0
      b.audience.find_each { |c| WhatsappNotifier.broadcast(b, c); n += 1 }
      b.update!(status: "sent", recipients: n, sent_at: Time.current)
      redirect_to whatsapp_broadcast_path(b), notice: "Sent to #{n} opted-in customers."
    end
  end
end
