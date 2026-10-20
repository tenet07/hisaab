module Gst
  # Works out taxable value and CGST+SGST (intra-state) or IGST (inter-state) per line, all in paise.
  # Counter bills can be tax-inclusive (MRP-style); wholesale bills are tax-exclusive.
  class Calculator
    Line = Struct.new(:product, :description, :hsn, :quantity, :rate_paise, :discount_pct, :gst_rate,
                      :taxable_paise, :cgst_paise, :sgst_paise, :igst_paise, :total_paise, keyword_init: true)

    attr_reader :lines, :interstate

    def initialize(interstate:, inclusive: false)
      @interstate, @inclusive, @lines = interstate, inclusive, []
    end

    def add(product:, quantity:, rate_paise:, discount_pct: 0, description: nil)
      qty, rate, disc, gst = quantity.to_i, rate_paise.to_i, discount_pct.to_d, product.gst_rate.to_d
      gross = (qty * rate * (100 - disc) / 100).round
      taxable = @inclusive ? (gross * 100 / (100 + gst)).round : gross
      tax = @inclusive ? gross - taxable : (taxable * gst / 100).round
      if interstate
        cgst = sgst = 0
        igst = tax
      else
        cgst = tax / 2
        sgst = tax - cgst
        igst = 0
      end
      @lines << Line.new(product: product, description: description || product.display_name, hsn: product.hsn, quantity: qty,
                         rate_paise: rate, discount_pct: disc, gst_rate: gst, taxable_paise: taxable,
                         cgst_paise: cgst, sgst_paise: sgst, igst_paise: igst, total_paise: taxable + tax)
      self
    end

    def taxable_paise = lines.sum(&:taxable_paise)
    def cgst_paise = lines.sum(&:cgst_paise)
    def sgst_paise = lines.sum(&:sgst_paise)
    def igst_paise = lines.sum(&:igst_paise)
    def exact_paise = taxable_paise + cgst_paise + sgst_paise + igst_paise
    # invoices round to the whole rupee
    def total_paise = ((exact_paise + 50) / 100) * 100
    def round_off_paise = total_paise - exact_paise
  end
end
