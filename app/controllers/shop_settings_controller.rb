class ShopSettingsController < ApplicationController
  before_action { redirect_to(root_path, alert: "Only the owner changes shop settings") unless current_user.owner? }
  before_action { @settings = ShopSetting.current }

  def edit; end

  def update
    attrs = params.require(:shop_setting).permit(:name, :address, :phone, :email, :gstin, :state_code,
      :invoice_prefix, :credit_note_prefix, :bank_name, :bank_account, :bank_ifsc, :upi_id, :bill_terms,
      :tally_company, tally_ledgers: ShopSetting::TALLY_KEYS)
    if @settings.update(attrs)
      redirect_to edit_settings_path, notice: "Shop settings saved"
    else
      render :edit, status: :unprocessable_entity
    end
  end
end
