class ClaimCreditsController < ApplicationController
  before_action :require_owner_or_accounts!
  def create
    claim = Claim.find(params[:claim_id])
    Books.record_claim_credit(claim: claim, number: params[:number], amount_paise: paise(params[:amount]),
                              user: current_user, date: Date.parse(params[:date]))
    redirect_to claim_path(claim), notice: "Brand credit note recorded; amount owed to supplier reduced"
  end
end
