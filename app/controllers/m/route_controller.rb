module M
  # Delivery person's day: today's runs, one drop at a time, proof by photo or customer OTP.
  class RouteController < BaseController
    before_action { authorize!(:route) unless Current.user.owner? }

    def show
      return drop_page if params[:id]
      scope = DispatchRun.for_date(Date.current).includes(:market, deliveries: { invoice: :customer })
      scope = scope.where(delivery_person: Current.user) unless Current.user.owner?
      @runs = scope.to_a
    end

    def update
      d = find_drop
      photo = params[:photo].presence
      Dispatch::Drop.complete!(d, otp: params[:otp], photo: photo, shortfall: params[:shortfall]&.to_unsafe_h || {},
                                  payment: { amount_paise: Money.to_paise(params[:amount]).to_i, mode: params[:mode], reference: params[:reference] },
                                  failed_reason: params[:failed_reason], client_uuid: params[:client_uuid])
      redirect_to m_route_path, notice: "#{d.customer.shop_name}: #{d.reload.status}."
    end

    def drop_page
      @drop = find_drop
      @invoice = @drop.invoice
      render :drop
    end

    private

    def find_drop
      d = Delivery.find(params[:id])
      raise Forbidden unless Current.user.owner? || d.dispatch_run.delivery_person_id == Current.user.id
      d
    end
  end
end
