module Reports
  # GSTR-3B summary: outward taxable supplies (3.1a), inter-state supplies to unregistered persons
  # by state (3.2), eligible ITC from purchases (4A5), and net tax payable.
  class Gstr3b
    attr_reader :from, :to

    def initialize(month)
      @from = month.beginning_of_month
      @to = month.end_of_month
    end

    def outward
      inv = Invoice.posted.where(invoice_date: from..to)
      cn = ::CreditNote.where(note_date: from..to)
      { taxable: inv.sum(:taxable_paise) - cn.sum(:taxable_paise), igst: inv.sum(:igst_paise) - cn.sum(:igst_paise),
        cgst: inv.sum(:cgst_paise) - cn.sum(:cgst_paise), sgst: inv.sum(:sgst_paise) - cn.sum(:sgst_paise) }
    end

    def interstate_unregistered
      Invoice.posted.where(invoice_date: from..to, bill_to_gstin: nil).where.not(place_of_supply: ShopSetting.current.state_code)
             .group(:place_of_supply).pluck(:place_of_supply, Arel.sql("SUM(taxable_paise)"), Arel.sql("SUM(igst_paise)"))
             .map { |pos, tx, ig| { pos: pos, taxable: tx.to_i, igst: ig.to_i } }
    end

    # ITC: purchases from in-state suppliers split CGST/SGST, others IGST
    def itc
      shop_state = ShopSetting.current.state_code
      res = { igst: 0, cgst: 0, sgst: 0 }
      Purchase.where(bill_date: from..to).includes(:supplier).each do |p|
        if (p.supplier.state_code || shop_state) == shop_state
          res[:cgst] += p.tax_paise / 2
          res[:sgst] += p.tax_paise - p.tax_paise / 2
        else
          res[:igst] += p.tax_paise
        end
      end
      res
    end

    def payable
      o, i = outward, itc
      %i[igst cgst sgst].index_with { [o[_1] - i[_1], 0].max }
    end
  end
end
