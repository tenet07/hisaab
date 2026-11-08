class SessionsController < ApplicationController
  skip_before_action :require_login
  # Second line of defence, per phone/computer (IP), across all logins.
  rate_limit to: 20, within: 10.minutes, only: :create,
             with: -> { redirect_to new_session_path, alert: "Too many tries from this phone. Wait 10 minutes." }
  def new
    return redirect_to(new_setup_path) unless User.exists?
    @users = User.active.order(:name)
  end
  def create
    user = User.active.find_by(id: params[:user_id])
    if user&.locked?
      redirect_to new_session_path, alert: "#{user.name} is locked after #{User::MAX_TRIES} wrong PINs. " \
                                           "Try after #{user.locked_until.in_time_zone.strftime('%H:%M')}" +
                                           (user.owner? ? "." : ", or ask the owner to set a new PIN.")
    elsif user&.authenticate(params[:pin])
      user.pin_ok!
      reset_session
      session[:user_id] = user.id
      redirect_to(user.delivery? ? run_deliveries_path : user.field? ? customers_path : root_path)
    else
      user&.pin_failed!
      msg = if user&.locked? then "Wrong PIN. #{user.name} is locked for #{User::LOCK_FOR.in_minutes.to_i} minutes."
            elsif user && (left = User::MAX_TRIES - user.failed_pins) < 3 then "Wrong PIN. #{left} #{'try'.pluralize(left)} left."
            else "Wrong PIN"
            end
      redirect_to new_session_path, alert: msg
    end
  end
  def destroy
    reset_session
    redirect_to new_session_path
  end
end
