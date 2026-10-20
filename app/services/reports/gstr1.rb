require "csv"

module Reports
  # GSTR-1 for a month: B2B, B2C large (inter-state, invoice > ₹1L... per current threshold), B2C small,
  # credit/debit notes (registered), HSN summary and document summary. CSV per table in the GST
  # Offline Tool's column order, plus portal JSON.
  class Gstr1
    B2CL_LIMIT = 10_000_000 # ₹1,00,000 in paise (inter-state B2C invoices above this are reported invoice-wise)

    attr_reader :from, :to, :shop

    def initialize(month)
      @from = month.beginning_of_month
      @to = month.end_of_month
      @shop = ShopSetting.current
    end

    def period = from.strftime("%m%Y")
    def invoices = @invoices ||= Invoice.posted.where(invoice_date: from..to).includes(:customer, lines: :product).order(:invoice_date, :id).to_a
    def cancelled = Invoice.where(status: "cancelled", invoice_date: from..to)
    def credit_notes = @cns ||= ::CreditNote.where(note_date: from..to).includes(:lines, :invoice).to_a

    def b2b = invoices.select(&:b2b?)
    def b2cl = invoices.reject(&:b2b?).select { _1.interstate? && _1.total_paise > B2CL_LIMIT }
    def b2cs_invoices = invoices.reject(&:b2b?) - b2cl

    def rate_rows(inv)
      inv.lines.group_by(&:gst_rate).map do |rate, ls|
        { rate: rate.to_f, taxable: ls.sum(&:taxable_paise), igst: ls.sum(&:igst_paise), cgst: ls.sum(&:cgst_paise), sgst: ls.sum(&:sgst_paise) }
      end
    end

    # B2C small is reported net: credit notes on B2C-small bills issued this month are deducted here
    def b2cs
      large = Invoice.posted.where(bill_to_gstin: nil).where.not(place_of_supply: shop.state_code).where("total_paise > ?", B2CL_LIMIT).pluck(:id).to_set
      notes = credit_notes.reject { _1.invoice.b2b? || large.include?(_1.invoice_id) }.flat_map do |n|
        n.lines.group_by(&:gst_rate).map do |rate, ls|
          tx, tax = -ls.sum(&:taxable_paise), -ls.sum(&:tax_paise)
          inter = n.igst_paise.positive?
          { rate: rate.to_f, taxable: tx, igst: inter ? tax : 0, cgst: inter ? 0 : tax / 2, sgst: inter ? 0 : tax - tax / 2,
            pos: n.invoice.place_of_supply, type: inter ? "INTER" : "INTRA" }
        end
      end
      (b2cs_invoices.flat_map { |i| rate_rows(i).map { _1.merge(pos: i.place_of_supply, type: i.interstate? ? "INTER" : "INTRA") } } + notes)
                   .group_by { [_1[:pos], _1[:rate], _1[:type]] }
                   .map { |(pos, rate, type), rs| { pos: pos, rate: rate, type: type, taxable: rs.sum { _1[:taxable] }, igst: rs.sum { _1[:igst] }, cgst: rs.sum { _1[:cgst] }, sgst: rs.sum { _1[:sgst] } } }
    end

    def cdnr = credit_notes.select { _1.invoice.b2b? }
    # credit notes on B2C-large invoices are reported individually (9B unregistered)
    def cdnur = credit_notes.select { !_1.invoice.b2b? && _1.invoice.interstate? && _1.invoice.total_paise > B2CL_LIMIT }

    UQC = { "pc" => "PCS", "pcs" => "PCS", "box" => "BOX", "m" => "MTR", "mtr" => "MTR", "coil" => "ROL", "roll" => "ROL", "set" => "SET", "kg" => "KGS" }.freeze
    UQC_LABEL = { "PCS" => "PCS-PIECES", "BOX" => "BOX-BOX", "MTR" => "MTR-METERS", "ROL" => "ROL-ROLLS", "SET" => "SET-SETS", "KGS" => "KGS-KILOGRAMS", "OTH" => "OTH-OTHERS" }.freeze

    def hsn
      invoices.flat_map(&:lines).group_by { [_1.hsn, _1.gst_rate, UQC[_1.product.unit.to_s.downcase] || "OTH"] }.map do |(code, rate, uqc), ls|
        { hsn: code, rate: rate.to_f, uqc: uqc, qty: ls.sum(&:quantity), value: ls.sum(&:total_paise), taxable: ls.sum(&:taxable_paise),
          igst: ls.sum(&:igst_paise), cgst: ls.sum(&:cgst_paise), sgst: ls.sum(&:sgst_paise) }
      end.sort_by { _1[:hsn] }
    end

    def totals
      { count: invoices.size, taxable: invoices.sum(&:taxable_paise), igst: invoices.sum(&:igst_paise), cgst: invoices.sum(&:cgst_paise),
        sgst: invoices.sum(&:sgst_paise), total: invoices.sum(&:total_paise), cn: credit_notes.sum(&:total_paise) }
    end

    def docs
      all = Invoice.where(invoice_date: from..to).order(:number).pluck(:number)
      cns = ::CreditNote.where(note_date: from..to).order(:number).pluck(:number)
      [["Invoices for outward supply", all.first, all.last, all.size, cancelled.count],
       ["Credit Note", cns.first, cns.last, cns.size, 0]].reject { _1[3].zero? }
    end

    def r(p) = format("%.2f", p / 100.0)
    def pos_label(code) = "#{code}-#{GstStates::NAMES[code]}"

    def csv(table)
      CSV.generate do |c|
        case table
        when "b2b"
          c << ["GSTIN/UIN of Recipient", "Receiver Name", "Invoice Number", "Invoice date", "Invoice Value", "Place Of Supply", "Reverse Charge", "Applicable % of Tax Rate", "Invoice Type", "E-Commerce GSTIN", "Rate", "Taxable Value", "Cess Amount"]
          b2b.each { |i| rate_rows(i).each { |x| c << [i.bill_to_gstin, i.bill_to_name, i.number, i.invoice_date.strftime("%d-%b-%Y"), r(i.total_paise), pos_label(i.place_of_supply), "N", "", "Regular B2B", "", x[:rate], r(x[:taxable]), "0.00"] } }
        when "b2cl"
          c << ["Invoice Number", "Invoice date", "Invoice Value", "Place Of Supply", "Applicable % of Tax Rate", "Rate", "Taxable Value", "Cess Amount", "E-Commerce GSTIN"]
          b2cl.each { |i| rate_rows(i).each { |x| c << [i.number, i.invoice_date.strftime("%d-%b-%Y"), r(i.total_paise), pos_label(i.place_of_supply), "", x[:rate], r(x[:taxable]), "0.00", ""] } }
        when "b2cs"
          c << ["Type", "Place Of Supply", "Applicable % of Tax Rate", "Rate", "Taxable Value", "Cess Amount", "E-Commerce GSTIN"]
          b2cs.each { |x| c << ["OE", pos_label(x[:pos]), "", x[:rate], r(x[:taxable]), "0.00", ""] }
        when "cdnr"
          c << ["GSTIN/UIN of Recipient", "Receiver Name", "Note Number", "Note Date", "Note Type", "Place Of Supply", "Reverse Charge", "Note Supply Type", "Note Value", "Applicable % of Tax Rate", "Rate", "Taxable Value", "Cess Amount"]
          cdnr.each { |n| n.lines.group_by(&:gst_rate).each { |rate, ls| c << [n.invoice.bill_to_gstin, n.invoice.bill_to_name, n.number, n.note_date.strftime("%d-%b-%Y"), "C", pos_label(n.invoice.place_of_supply), "N", "Regular B2B", r(n.total_paise), "", rate.to_f, r(ls.sum(&:taxable_paise)), "0.00"] } }
        when "cdnur"
          c << ["UR Type", "Note Number", "Note Date", "Note Type", "Place Of Supply", "Note Value", "Applicable % of Tax Rate", "Rate", "Taxable Value", "Cess Amount"]
          cdnur.each { |n| n.lines.group_by(&:gst_rate).each { |rate, ls| c << ["B2CL", n.number, n.note_date.strftime("%d-%b-%Y"), "C", pos_label(n.invoice.place_of_supply), r(n.total_paise), "", rate.to_f, r(ls.sum(&:taxable_paise)), "0.00"] } }
        when "hsn"
          c << ["HSN", "Description", "UQC", "Total Quantity", "Total Value", "Rate", "Taxable Value", "Integrated Tax Amount", "Central Tax Amount", "State/UT Tax Amount", "Cess Amount"]
          hsn.each { |h| c << [h[:hsn], "", UQC_LABEL[h[:uqc]], h[:qty], r(h[:value]), h[:rate], r(h[:taxable]), r(h[:igst]), r(h[:cgst]), r(h[:sgst]), "0.00"] }
        when "docs"
          c << ["Nature of Document", "Sr. No. From", "Sr. No. To", "Total Number", "Cancelled"]
          docs.each { c << _1 }
        end
      end
    end

    TABLES = %w[b2b b2cl b2cs cdnr cdnur hsn docs].freeze

    # GSTN portal JSON (subset the shop actually needs)
    def to_json(*)
      f = ->(p) { (p / 100.0).round(2) }
      {
        gstin: shop.gstin, fp: period, version: "GST3.1.6", hash: "hash",
        b2b: b2b.group_by(&:bill_to_gstin).map do |ctin, invs|
          { ctin: ctin, inv: invs.map do |i|
            { inum: i.number, idt: i.invoice_date.strftime("%d-%m-%Y"), val: f[i.total_paise], pos: i.place_of_supply, rchrg: "N", inv_typ: "R",
              itms: rate_rows(i).each_with_index.map { |x, n| { num: n + 1, itm_det: { rt: x[:rate], txval: f[x[:taxable]], iamt: f[x[:igst]], camt: f[x[:cgst]], samt: f[x[:sgst]], csamt: 0 } } } }
          end }
        end,
        b2cs: b2cs.map { |x| { sply_ty: x[:type], pos: x[:pos], typ: "OE", rt: x[:rate], txval: f[x[:taxable]], iamt: f[x[:igst]], camt: f[x[:cgst]], samt: f[x[:sgst]], csamt: 0 } },
        cdnr: cdnr.group_by { _1.invoice.bill_to_gstin }.map do |ctin, ns|
          { ctin: ctin, nt: ns.map { |n| { ntty: "C", nt_num: n.number, nt_dt: n.note_date.strftime("%d-%m-%Y"), val: f[n.total_paise], pos: n.invoice.place_of_supply, rchrg: "N", inv_typ: "R",
                                         itms: n.lines.group_by(&:gst_rate).each_with_index.map { |(rate, ls), k| { num: k + 1, itm_det: { rt: rate.to_f, txval: f[ls.sum(&:taxable_paise)], iamt: f[n.igst_paise.positive? ? ls.sum(&:tax_paise) : 0], camt: f[n.igst_paise.positive? ? 0 : ls.sum(&:tax_paise) / 2], samt: f[n.igst_paise.positive? ? 0 : ls.sum(&:tax_paise) - ls.sum(&:tax_paise) / 2], csamt: 0 } } } } } }
        end,
        hsn: { data: hsn.each_with_index.map { |h, i| { num: i + 1, hsn_sc: h[:hsn], uqc: h[:uqc], qty: h[:qty], rt: h[:rate], txval: f[h[:taxable]], iamt: f[h[:igst]], camt: f[h[:cgst]], samt: f[h[:sgst]], csamt: 0 } } }
      }.to_json
    end
  end
end
