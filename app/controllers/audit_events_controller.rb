# Who did what, when, from which device — master changes plus every ledger posting.
class AuditEventsController < ApplicationController
  require_permission :audit

  def index
    @tab = params[:tab].presence || "postings"
    if @tab == "postings"
      @rows = LedgerEntry.includes(:party, :user).order(created_at: :desc).limit(200)
    else
      scope = AuditEvent.includes(:user, :subject).recent
      scope = scope.where(user_id: params[:user_id]) if params[:user_id].present?
      @rows = scope.limit(200)
    end
  end
end
