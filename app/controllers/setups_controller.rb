# A brand-new installation has no users: create the owner first.
class SetupsController < ApplicationController
  skip_before_action :require_login
  before_action { redirect_to new_session_path if User.exists? }
  def new
    @user = User.new(role: "owner")
    @settings = ShopSetting.current
  end

  # On the internet, a fresh server's setup page must not be claimable by a stranger:
  # it asks for the SETUP_CODE written in the server's .env file.
  def self.code_required? = Rails.env.production? || ENV["SETUP_CODE"].present?

  def create
    if self.class.code_required? &&
       !(ENV["SETUP_CODE"].present? && ActiveSupport::SecurityUtils.secure_compare(params[:setup_code].to_s.strip, ENV["SETUP_CODE"]))
      @user = User.new(name: params.dig(:user, :name), role: "owner")
      @settings = ShopSetting.current
      @setup_error = ENV["SETUP_CODE"].blank? ? "SETUP_CODE is not set on the server (see DEPLOY.md)" : "Setup code is wrong"
      return render(:new, status: :unprocessable_entity)
    end
    @user = User.new(name: params[:user][:name], password: params[:user][:password], role: "owner")
    @settings = ShopSetting.current
    @settings.assign_attributes(params.fetch(:shop, {}).permit(:name, :gstin, :state_code))
    ok = ApplicationRecord.transaction do
      raise ActiveRecord::Rollback unless @settings.save && @user.save
      true
    end
    if ok
      session[:user_id] = @user.id
      redirect_to edit_settings_path, notice: "Welcome! Finish your shop details, then add staff and import your data."
    else
      render :new, status: :unprocessable_entity
    end
  end
end
