# Delivery challan for defective pieces sent to a brand under one claim.
class ChallanPdf < BasePdf
  def initialize(claim)
    super()
    letterhead("DELIVERY CHALLAN — WARRANTY CLAIM", "Not a sale. Goods sent for warranty replacement.")
    two_col(-> {
      text "To", color: MUTED
      text claim.supplier&.name || claim.brand.name, style: :bold, size: 10
      text claim.brand.claim_contact.to_s
    }, -> {
      kv "Challan no.", claim.challan_no.presence || "(draft)"
      kv "Claim", claim.number
      kv "Date", (claim.sent_on || Date.current).strftime("%d %b %Y")
      kv "Pieces", claim.pieces
    })
    move_down 12
    rows = [["#", "Ref", "Item", "Serial", "Defect", "Sold on", "Customer"]] + claim.replacements.includes(:product, :customer).each_with_index.map do |r, i|
      [i + 1, r.number, r.product.display_name, r.serial_no.to_s, r.defect.to_s, r.sold_on&.strftime("%d %b %Y").to_s, r.customer.code]
    end
    t = make_table(rows, width: bounds.width, header: true)
    table_style(t)
    t.draw
    move_down 30
    text "Received by (brand)", color: MUTED
    move_down 24
    stroke_horizontal_line 0, 160
    footer_note "Pieces are claimed under the brand's warranty; please return replacements or a credit note quoting #{claim.number}."
  end
end
