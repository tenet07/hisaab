class PinsController < ApplicationController
  def edit; end
  def update
    unless current_user.authenticate(params[:current_pin])
      return redirect_to(edit_pin_path, alert: "Current PIN is wrong")
    end
    if params[:pin] != params[:pin_confirmation]
      return redirect_to(edit_pin_path, alert: "The two new PINs don't match")
    end
    if current_user.update(password: params[:pin])
      redirect_to root_path, notice: "PIN changed"
    else
      redirect_to edit_pin_path, alert: current_user.errors.full_messages.to_sentence
    end
  end
end
