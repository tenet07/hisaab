class DeliveriesController < ApplicationController
  require_permission :dispatch
  before_action :require_writer!

  # Desktop override: close a drop with the OTP the customer read out over the phone, or mark it failed.
  def update
    d = Delivery.find(params[:id])
    Dispatch::Drop.complete!(d, otp: params[:otp], photo: params[:photo], failed_reason: params[:failed_reason])
    redirect_to d.dispatch_run, notice: "Drop updated."
  end
end
