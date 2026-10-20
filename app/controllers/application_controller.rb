class ApplicationController < ActionController::Base
  include Authentication
  # phones a few years old must still work at the counter and on the road
  allow_browser versions: { safari: 16.4, chrome: 105, firefox: 115, opera: 91, ie: false }
  before_action :stamp_device
  helper_method :can?, :shop

  rescue_from ActiveRecord::RecordInvalid, with: ->(e) { fail_back(e.record.errors.full_messages.to_sentence) }
  rescue_from Invoicing::Post::Error, Invoicing::Cancel::Error, Invoicing::CreditNote::Error, Payments::Record::Error,
              Replacements::Intake::Error, Claims::Batch::Error, Approvals::Error, Stock::Count::Error,
              Stock::PurchaseEntry::Error, Dispatch::Drop::Error, ArgumentError, with: ->(e) { fail_back(e.message) }

  class Forbidden < StandardError; end
  rescue_from Forbidden do
    respond_to do |f|
      f.html { redirect_to(Current.user&.mobile_first? ? m_root_path : root_path, alert: "Your role can't open that page.") }
      f.json { render json: { error: "forbidden" }, status: :forbidden }
    end
  end

  private

  def shop = ShopSetting.current
  def can?(perm) = Current.user&.can?(perm)

  def self.require_permission(perm, **opts)
    before_action(**opts) { authorize!(perm) }
  end

  def authorize!(perm)
    raise Forbidden unless can?(perm)
  end

  # Read-only roles (CA) can view but never post.
  def require_writer!
    raise Forbidden if Current.user&.read_only?
  end

  def stamp_device
    Current.device = Current.session&.device_label || Session.label_for(request.user_agent)
  end

  def fail_back(message)
    respond_to do |f|
      f.html { redirect_back fallback_location: root_path, alert: message }
      f.turbo_stream { flash.now[:alert] = message; render turbo_stream: turbo_stream.update("flash", partial: "shared/flash") }
      f.json { render json: { error: message }, status: :unprocessable_entity }
    end
  end

  def paise(param) = Money.to_paise(param)
  def date_param(v, default = Date.current) = (Date.parse(v.to_s) rescue default)
end
