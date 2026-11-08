class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  before_action :require_login
  before_action :keep_delivery_staff_on_their_run
  helper_method :current_user
  rescue_from Books::Error, with: :books_error

  private

  def current_user = @current_user ||= User.active.find_by(id: session[:user_id])

  def require_login
    redirect_to new_session_path unless current_user
  end

  # Delivery staff see their run and nothing else (no balances, no stock).
  def keep_delivery_staff_on_their_run
    return unless current_user&.delivery?
    return if %w[deliveries sessions pins].include?(controller_name)
    redirect_to run_deliveries_path
  end

  def require_office!
    redirect_to root_path, alert: "Not allowed for your role" unless current_user.office?
  end

  def require_owner_or_accounts!
    redirect_to root_path, alert: "Only owner or accounts" unless %w[owner accounts].include?(current_user.role)
  end

  def books_error(e)
    redirect_back fallback_location: root_path, alert: e.message
  end

  def paise(param) = Shop::Money.paise(param.to_s.strip.presence || "0")
end
