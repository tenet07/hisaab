module Claims
  # Brand claim lifecycle: batch awaiting pieces per brand → send with challan → settle
  # (credit note, possibly partial, and/or replacement pieces) → anything rejected goes for write-off.
  module Batch
    class Error < StandardError; end
    module_function

    def build(brand, replacements)
      held = Approval.pending.where(kind: "write_off", subject_type: "Replacement").pluck(:subject_id).to_set
      replacements = replacements.select { _1.claim_status == "awaiting" && _1.product.brand_id == brand.id && _1.brand_claim_id.nil? && !held.include?(_1.id) }
      raise Error, "No pieces awaiting a claim for #{brand.name}" if replacements.empty?
      BrandClaim.transaction do
        claim = BrandClaim.create!(brand: brand, supplier: brand.suppliers.first, created_by: Current.user)
        replacements.each { _1.update!(brand_claim: claim) }
        claim
      end
    end

    def dispatch!(claim, challan_no:, sent_on: Date.current)
      raise Error, "This claim was already sent" unless claim.status == "open"
      raise Error, "Enter the challan number" if challan_no.blank?
      BrandClaim.transaction do
        claim.replacements.each do |r|
          raise Error, "#{r.number} is #{r.status_label.downcase}; take it off this claim" unless r.claim_status == "awaiting"
          Approval.pending.where(subject: r, kind: "write_off").find_each { _1.update!(status: "void", reason: "#{_1.reason} — voided: sent to brand") }
          StockMovement.post!([
            { product: r.product, bucket: "awaiting_claim", quantity: -1, reason: "claim_sent", document: claim },
            { product: r.product, bucket: "with_brand", quantity: 1, reason: "claim_sent", document: claim }
          ])
          r.update!(claim_status: "with_brand")
        end
        claim.update!(status: "sent", challan_no: challan_no, sent_on: sent_on)
        claim
      end
    end

    # outcomes: { replacement_id => { result: "replaced"|"credited"|"rejected", amount_paise: } }
    # Pieces not listed stay with the brand (partial settlement).
    def settle!(claim, outcomes:, credit_note_ref: nil, date: Date.current)
      raise Error, "Send the claim before settling it" unless claim.sent?
      BrandClaim.transaction do
        credited = 0
        claim.replacements.select(&:open?).each do |r|
          o = outcomes[r.id] || outcomes[r.id.to_s]
          next if o.blank? || o[:result].blank?
          case o[:result].to_s
          when "replaced"
            StockMovement.post!([
              { product: r.product, bucket: "with_brand", quantity: -1, reason: "claim_replaced", document: claim },
              { product: r.product, bucket: "sellable", quantity: 1, reason: "claim_replaced", document: claim }
            ])
            r.update!(claim_status: "replaced")
          when "credited"
            amt = o[:amount_paise].to_i
            raise Error, "Enter the credited amount for #{r.number}" unless amt.positive?
            StockMovement.create!(product: r.product, bucket: "with_brand", quantity: -1, reason: "claim_credited", document: claim)
            r.update!(claim_status: "credited", credited_paise: amt)
            credited += amt
          when "rejected"
            # piece comes back to the shop and waits for the owner to approve writing it off
            StockMovement.post!([
              { product: r.product, bucket: "with_brand", quantity: -1, reason: "claim_rejected", document: claim },
              { product: r.product, bucket: "awaiting_claim", quantity: 1, reason: "claim_rejected", document: claim }
            ])
            r.update!(claim_status: "rejected")
            Approvals.request!(r, kind: "write_off", reason: "Rejected by #{claim.brand.name} on #{claim.number}",
                                  amount_paise: r.product.purchase_paise)
          else raise Error, "Unknown outcome #{o[:result]}"
          end
        end
        if credited.positive? && claim.supplier
          LedgerEntry.create!(party: claim.supplier, entry_date: date, debit_paise: credited, entry_type: "credit_note",
                              document: claim, narration: "Brand credit #{credit_note_ref} on #{claim.number}")
        end
        claim.update!(credited_paise: claim.credited_paise + credited,
                      credit_note_ref: [claim.credit_note_ref, credit_note_ref.presence].compact.uniq.join(", ").presence)
        claim.replacements.reload
        claim.update!(status: "settled", settled_on: date) if claim.open_pieces.empty?
        claim
      end
    end
  end
end
