# Things that need the owner's say-so: writing off defective stock, discounts over the limit,
# bills over a customer's credit limit, large count adjustments.
module Approvals
  class Error < StandardError; end
  module_function

  def request!(subject, kind:, reason:, amount_paise: nil)
    existing = Approval.pending.find_by(subject: subject, kind: kind)
    return existing if existing
    Approval.create!(subject: subject, kind: kind, reason: reason, amount_paise: amount_paise, requested_by: Current.user)
  end

  def decide!(approval, approve:, note: nil)
    raise Error, "Only the owner can decide approvals" unless Current.user&.owner?
    raise Error, "Already decided" unless approval.pending?
    Approval.transaction do
      approval.update!(status: approve ? "approved" : "rejected", decided_by: Current.user, decided_at: Time.current,
                       reason: [approval.reason, note.presence].compact.join(" — "))
      execute!(approval) if approve
      undo!(approval) unless approve
      AuditEvent.log!(approval, approve ? "approved" : "rejected", { "kind" => approval.kind })
      approval
    end
  end

  # A refused write-off puts a brand-rejected piece back in the claim queue to try again
  def undo!(approval)
    r = approval.subject
    r.update!(claim_status: "awaiting", brand_claim: nil) if approval.kind == "write_off" && r.claim_status == "rejected"
  end

  def execute!(approval)
    case approval.kind
    when "write_off"
      r = approval.subject.lock!
      unless %w[awaiting rejected].include?(r.claim_status) && (r.brand_claim.nil? || r.claim_status == "rejected")
        raise Error, "#{r.number} is #{r.status_label.downcase} now — it can't be written off"
      end
      StockMovement.post!([
        { product: r.product, bucket: "awaiting_claim", quantity: -1, reason: "write_off", document: r },
        { product: r.product, bucket: "written_off", quantity: 1, reason: "write_off", document: r }
      ])
      r.update!(claim_status: "written_off")
    when "stock_adjustment"
      Stock::Count.post!(approval.subject, approved: true)
    end
  end
end
