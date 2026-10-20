class SettingsController < ApplicationController
  before_action { raise Forbidden unless Current.user.owner? }

  def show = @s = shop

  def update
    @s = shop
    p = params.require(:shop_setting).permit(:name, :legal_name, :gstin, :state_code, :address, :phone, :email, :upi_id, :invoice_prefix,
                                             :credit_days, :eway_threshold, :einvoice_enabled, :claim_flag_days, :discount_approval_pct,
                                             :writeoff_approval, :whatsapp_provider, :bank_details)
    if @s.update(p)
      AuditEvent.log!(@s, "settings", @s.saved_changes.except("updated_at"))
      redirect_to settings_path, notice: "Settings saved."
    else
      render :show, status: :unprocessable_entity
    end
  end
end
