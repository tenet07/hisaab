class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: "Too many attempts. Try again in a few minutes." }
  layout "auth"

  def new; end

  def create
    user = User.active.authenticate_by(params.permit(:email_address, :password))
    if user
      start_new_session_for user
      Current.session.update_columns(device_label: Session.label_for(request.user_agent))
      redirect_to(user.mobile_first? ? m_root_path : after_authentication_url)
    else
      redirect_to new_session_path, alert: "That email and password don't match."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, notice: "Signed out"
  end
end
