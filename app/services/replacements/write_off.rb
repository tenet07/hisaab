module Replacements
  module WriteOff
    module_function

    # Asks the owner to write off a piece that can't be claimed (out of warranty, brand won't take it).
    def request!(replacement, reason:)
      raise Approvals::Error, "Only pieces still in the shop can be written off" unless %w[awaiting rejected].include?(replacement.claim_status)
      Approvals.request!(replacement, kind: "write_off", reason: reason, amount_paise: replacement.product.purchase_paise)
    end
  end
end
