class UsersController < ApplicationController
  before_action { raise Forbidden unless Current.user.owner? }
  before_action :set_user, only: %i[edit update]

  def index = @users = User.order(:role, :name)
  def new = @user = User.new(role: "counter")
  def edit; end

  def create
    @user = User.new(user_params)
    @user.save ? redirect_to(users_path, notice: "#{@user.name} can sign in now.") : render(:new, status: :unprocessable_entity)
  end

  def update
    p = user_params
    p = p.except(:password) if p[:password].blank?
    raise ArgumentError, "You can't remove your own owner access" if @user == Current.user && (p[:role] != "owner" || p[:active] == "0")
    if @user.update(p)
      @user.sessions.destroy_all if !@user.active? || @user.saved_change_to_password_digest?
      redirect_to users_path, notice: "Saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user = @user = User.find(params[:id])
  def user_params = params.require(:user).permit(:name, :email_address, :phone, :role, :password, :active)
end
