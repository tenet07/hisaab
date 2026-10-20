module M
  # The phone app for salesmen and delivery staff.
  class BaseController < ApplicationController
    layout "mobile"
    before_action :require_mobile

    private

    def require_mobile = authorize!(:mobile)
  end
end
