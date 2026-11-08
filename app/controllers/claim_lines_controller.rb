class ClaimLinesController < ApplicationController
  before_action :require_office!
  def settle
    line = ClaimLine.find(params[:id])
    Books.settle_claim_line(line, new_qty: params[:new_qty], credit_qty: params[:credit_qty],
                                  rejected_qty: params[:rejected_qty], user: current_user)
    redirect_to claim_path(line.claim), notice: "Claim line updated"
  end
end
