class UsersController < ApplicationController
  before_action :require_owner!
  before_action :set_user, only: %i[edit update]

  def index = @users = User.order(active: :desc, role: :asc, name: :asc)
  def new = @user = User.new(role: "counter", active: true)
  def edit; end

  def create
    @user = User.new(user_params)
    @user.save ? redirect_to(users_path, notice: "#{@user.name} added") : render(:new, status: :unprocessable_entity)
  end

  def update
    attrs = user_params
    attrs.delete(:password) if attrs[:password].blank?
    if @user == current_user && (attrs[:active] == "0" || (attrs[:role].present? && attrs[:role] != "owner"))
      return redirect_to(edit_user_path(@user), alert: "You can't remove your own owner access")
    end
    @user.update(attrs) ? redirect_to(users_path, notice: "Saved") : render(:edit, status: :unprocessable_entity)
  end

  private

  def require_owner!
    redirect_to root_path, alert: "Only the owner manages staff" unless current_user.owner?
  end

  def set_user = @user = User.find(params[:id])
  def user_params = params.require(:user).permit(:name, :role, :password, :active)
end
