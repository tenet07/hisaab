class ApprovalsController < ApplicationController
  before_action { raise Forbidden unless Current.user.owner? || can?(:approvals_request) }

  def index
    @pending = Approval.pending.includes(:subject, :requested_by).recent
    @recent = Approval.where.not(status: "pending").includes(:subject, :decided_by).recent.limit(30)
  end

  def approve = decide(true)
  def reject = decide(false)

  private

  def decide(ok)
    a = Approvals.decide!(Approval.find(params[:id]), approve: ok, note: params[:note])
    msg = ok ? "Approved: #{a.kind_label.downcase}." : "Rejected."
    msg += " You can now bill #{a.subject.number}." if ok && a.kind == "discount"
    redirect_to approvals_path, notice: msg
  end
end
