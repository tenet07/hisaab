module Gst
  # E-invoicing (mandatory above ₹5 Cr turnover): builds the NIC IRP JSON (schema 1.1) for a B2B
  # invoice and sends it through the shop's GST API provider (GSP), storing the IRN it returns.
  # Configure GST_API_URL / GST_API_KEY (provider endpoint that accepts the NIC payload).
  module Einvoice
    module_function

    def configured? = ENV["GST_API_URL"].present? && ENV["GST_API_KEY"].present?
    def applies?(inv) = ShopSetting.current.einvoice_enabled && inv.b2b? && inv.posted? && inv.irn.blank?

    def payload(inv)
      shop = ShopSetting.current
      r = ->(p) { (p / 100.0).round(2) }
      {
        Version: "1.1",
        TranDtls: { TaxSch: "GST", SupTyp: "B2B", RegRev: "N" },
        DocDtls: { Typ: "INV", No: inv.number, Dt: inv.invoice_date.strftime("%d/%m/%Y") },
        SellerDtls: { Gstin: shop.gstin, LglNm: shop.legal_name.presence || shop.name, Addr1: shop.address.to_s.first(100), Loc: shop.address.to_s.split(",").last.to_s.strip.first(50).presence || "NA",
                      Pin: shop.address.to_s[/\b\d{6}\b/].to_i, Stcd: shop.state_code },
        BuyerDtls: { Gstin: inv.bill_to_gstin, LglNm: inv.bill_to_name, Pos: inv.place_of_supply, Addr1: inv.bill_to_address.to_s.first(100).presence || "NA",
                     Loc: "NA", Pin: inv.bill_to_address.to_s[/\b\d{6}\b/].to_i.nonzero? || 999999, Stcd: Gstin.state_code(inv.bill_to_gstin) },
        ItemList: inv.lines.each_with_index.map do |l, i|
          { SlNo: (i + 1).to_s, PrdDesc: l.description, IsServc: "N", HsnCd: l.hsn, Qty: l.quantity, Unit: "PCS",
            UnitPrice: r[l.rate_paise], TotAmt: r[l.rate_paise * l.quantity], Discount: r[l.rate_paise * l.quantity - l.taxable_paise],
            AssAmt: r[l.taxable_paise], GstRt: l.gst_rate.to_f, IgstAmt: r[l.igst_paise], CgstAmt: r[l.cgst_paise], SgstAmt: r[l.sgst_paise],
            TotItemVal: r[l.total_paise] }
        end,
        ValDtls: { AssVal: r[inv.taxable_paise], CgstVal: r[inv.cgst_paise], SgstVal: r[inv.sgst_paise], IgstVal: r[inv.igst_paise],
                   RndOffAmt: r[inv.round_off_paise], TotInvVal: r[inv.total_paise] }
      }
    end

    def generate!(inv)
      return unless applies?(inv)
      raise "GST API provider not configured (GST_API_URL / GST_API_KEY)" unless configured?
      res = Net::HTTP.post(URI(ENV["GST_API_URL"]), payload(inv).to_json,
                           "Content-Type" => "application/json", "Authorization" => "Bearer #{ENV['GST_API_KEY']}")
      json = JSON.parse(res.body) rescue {}
      irn = json["Irn"] || json.dig("data", "Irn") || json.dig("result", "Irn")
      raise "IRN not returned: #{json['message'] || res.code}" unless res.is_a?(Net::HTTPSuccess) && irn
      inv.update!(irn: irn, eway_bill_no: inv.eway_bill_no || json["EwbNo"]&.to_s)
      AuditEvent.log!(inv, "irn_generated", { "irn" => irn })
      irn
    end
  end
end
