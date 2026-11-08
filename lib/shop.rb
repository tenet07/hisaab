# frozen_string_literal: true

# Shop core: the rules that keep stock, balances and GST correct.
# Plain Ruby, no Rails or gems, so it can be unit-tested anywhere and
# called from Rails models/services unchanged.
#
# Money is ALWAYS integer paise. GST rates are basis points (18% = 1800).

require "date"

module Shop
  class Error < StandardError; end
  class InsufficientStock < Error; end
  class InvalidMove < Error; end

  # ---------------------------------------------------------------- money
  module Money
    module_function

    def paise(rupees)
      raise ArgumentError, "use String/Integer, never Float, for money" if rupees.is_a?(Float)
      (Rational(rupees.to_s) * 100).round(half: :up).to_i
    end

    # integer division rounded half-up (non-negative numerators)
    def div_round(num, den)
      q, r = num.divmod(den)
      r * 2 >= den ? q + 1 : q
    end

    def format(p)
      sign = p.negative? ? "-" : ""
      rupees, ps = p.abs.divmod(100)
      "#{sign}₹#{indian(rupees)}.#{ps.to_s.rjust(2, '0')}"
    end

    ONES = %w[Zero One Two Three Four Five Six Seven Eight Nine Ten Eleven Twelve Thirteen Fourteen
              Fifteen Sixteen Seventeen Eighteen Nineteen].freeze
    TENS = %w[_ _ Twenty Thirty Forty Fifty Sixty Seventy Eighty Ninety].freeze

    # 206300 paise -> "Rupees Two Thousand Sixty-Three Only" (Indian lakh/crore system)
    def words(p)
      raise ArgumentError, "amount can't be negative" if p.negative?
      rupees, ps = p.divmod(100)
      out = "Rupees #{rupees.zero? ? 'Zero' : number_words(rupees)}"
      out += " and #{number_words(ps)} Paise" if ps.positive?
      "#{out} Only"
    end

    def number_words(n)
      parts = []
      [[10_000_000, "Crore"], [100_000, "Lakh"], [1000, "Thousand"], [100, "Hundred"]].each do |size, name|
        next if n < size
        count, n = n.divmod(size)
        parts << "#{size == 10_000_000 ? number_words(count) : below_hundred(count)} #{name}"
      end
      parts << below_hundred(n) if n.positive?
      parts.join(" ")
    end

    def below_hundred(n)
      return ONES[n] if n < 20
      t, o = n.divmod(10)
      o.zero? ? TENS[t] : "#{TENS[t]}-#{ONES[o]}"
    end

    # 1234567 -> "12,34,567"
    def indian(n)
      s = n.to_s
      return s if s.size <= 3
      head, tail = s[0..-4], s[-3..]
      head.reverse.scan(/\d{1,2}/).join(",").reverse + "," + tail
    end
  end

  # GST state codes (first two digits of a GSTIN), for "place of supply".
  STATES = {
    "01" => "Jammu and Kashmir", "02" => "Himachal Pradesh", "03" => "Punjab", "04" => "Chandigarh",
    "05" => "Uttarakhand", "06" => "Haryana", "07" => "Delhi", "08" => "Rajasthan", "09" => "Uttar Pradesh",
    "10" => "Bihar", "11" => "Sikkim", "12" => "Arunachal Pradesh", "13" => "Nagaland", "14" => "Manipur",
    "15" => "Mizoram", "16" => "Tripura", "17" => "Meghalaya", "18" => "Assam", "19" => "West Bengal",
    "20" => "Jharkhand", "21" => "Odisha", "22" => "Chhattisgarh", "23" => "Madhya Pradesh", "24" => "Gujarat",
    "26" => "Dadra and Nagar Haveli and Daman and Diu", "27" => "Maharashtra", "29" => "Karnataka", "30" => "Goa",
    "31" => "Lakshadweep", "32" => "Kerala", "33" => "Tamil Nadu", "34" => "Puducherry",
    "35" => "Andaman and Nicobar Islands", "36" => "Telangana", "37" => "Andhra Pradesh", "38" => "Ladakh",
    "97" => "Other Territory"
  }.freeze

  # ------------------------------------------------------------------ GST
  # A line priced per unit. price_includes_tax true for MRP-style retail
  # pricing, false for wholesale rates quoted before GST.
  Line = Struct.new(:sku, :name, :hsn, :qty, :unit_price_paise, :gst_bp,
                    :discount_paise, :price_includes_tax, keyword_init: true) do
    def initialize(**kw)
      super
      self.discount_paise ||= 0
      self.price_includes_tax = false if price_includes_tax.nil?
      raise ArgumentError, "qty must be positive" unless qty.to_i.positive?
    end
  end

  TaxedLine = Struct.new(:line, :taxable, :cgst, :sgst, :igst, keyword_init: true) do
    def tax = cgst + sgst + igst
    def total = taxable + tax
  end

  module GST
    module_function

    # intra_state: buyer in same state -> CGST+SGST split; else IGST.
    def tax_line(line, intra_state:)
      gross = line.qty * line.unit_price_paise - line.discount_paise
      raise ArgumentError, "discount exceeds line value" if gross.negative?

      taxable =
        if line.price_includes_tax
          Money.div_round(gross * 10_000, 10_000 + line.gst_bp)
        else
          gross
        end
      tax = Money.div_round(taxable * line.gst_bp, 10_000)
      if line.price_includes_tax
        # keep the customer's total exactly equal to the printed price
        tax = gross - taxable
      end

      if intra_state
        cgst = tax / 2
        TaxedLine.new(line: line, taxable: taxable, cgst: cgst, sgst: tax - cgst, igst: 0)
      else
        TaxedLine.new(line: line, taxable: taxable, cgst: 0, sgst: 0, igst: tax)
      end
    end
  end

  # -------------------------------------------------------------- invoice
  class Invoice
    attr_reader :number, :date, :customer_id, :lines, :intra_state

    def initialize(number:, date:, customer_id:, lines:, intra_state: true)
      raise ArgumentError, "invoice needs at least one line" if lines.empty?
      @number, @date, @customer_id, @intra_state = number, date, customer_id, intra_state
      @lines = lines.map { |l| GST.tax_line(l, intra_state: intra_state) }
    end

    def taxable = lines.sum(&:taxable)
    def cgst = lines.sum(&:cgst)
    def sgst = lines.sum(&:sgst)
    def igst = lines.sum(&:igst)
    def tax = cgst + sgst + igst
    def exact_total = taxable + tax

    # bill rounded to the nearest rupee, as printed
    def total = Money.div_round(exact_total, 100) * 100
    def round_off = total - exact_total

    # tax summary by HSN + rate, needed on B2B invoices and in GSTR-1
    def hsn_summary
      lines.group_by { |t| [t.line.hsn, t.line.gst_bp] }.map do |(hsn, bp), ts|
        { hsn: hsn, gst_bp: bp, qty: ts.sum { |t| t.line.qty },
          taxable: ts.sum(&:taxable), tax: ts.sum(&:tax) }
      end
    end

    E_WAY_BILL_THRESHOLD = 50_000_00 # ₹50,000; check state rules with the CA
    def needs_eway_bill? = total > E_WAY_BILL_THRESHOLD
  end

  # ---------------------------------------------------------- stock ledger
  # Stock is never stored; it is the sum of movements per (sku, bucket).
  BUCKETS = %i[sellable awaiting_claim with_brand written_off].freeze
  Movement = Struct.new(:sku, :bucket, :qty, :reason, :ref, :at, :by, keyword_init: true)

  class StockLedger
    attr_reader :movements

    def initialize = @movements = []

    def balance(sku, bucket = :sellable)
      @movements.sum { |m| m.sku == sku && m.bucket == bucket ? m.qty : 0 }
    end

    def snapshot(sku) = BUCKETS.to_h { |b| [b, balance(sku, b)] }

    def opening(sku, qty, by:) = post([[sku, :sellable, qty]], :opening, nil, by)
    def purchase(sku, qty, ref:, by:) = post([[sku, :sellable, qty]], :purchase, ref, by)

    def sale(invoice, by:)
      moves = invoice.lines.map { |t| [t.line.sku, :sellable, -t.line.qty] }
      post(moves, :sale, invoice.number, by)
    end

    def sale_return(sku, qty, ref:, by:) = post([[sku, :sellable, qty]], :sale_return, ref, by)

    # Customer brings a defective piece, gets a good one from the shelf.
    def replacement(sku, qty: 1, ref:, by:)
      post([[sku, :sellable, -qty], [sku, :awaiting_claim, qty]], :replacement, ref, by)
    end

    # Batch of defective pieces handed to the brand / distributor.
    def send_claim(sku, qty, ref:, by:)
      post([[sku, :awaiting_claim, -qty], [sku, :with_brand, qty]], :claim_sent, ref, by)
    end

    # Brand settles. :credit_note => money via supplier ledger, no stock back.
    #                :new_piece   => replacement goods return to the shelf.
    def settle_claim(sku, qty, mode:, ref:, by:)
      moves = [[sku, :with_brand, -qty]]
      case mode
      when :credit_note then nil
      when :new_piece then moves << [sku, :sellable, qty]
      else raise ArgumentError, "mode must be :credit_note or :new_piece"
      end
      post(moves, :claim_settled, ref, by)
    end

    def reject_claim(sku, qty, ref:, by:, approved_by:)
      raise InvalidMove, "write-off needs owner approval" if approved_by.to_s.empty?
      post([[sku, :with_brand, -qty], [sku, :written_off, qty]], :claim_rejected, ref, by)
    end

    # Physical count differs: post the difference with a reason, never overwrite.
    def count_adjustment(sku, counted:, reason:, by:)
      raise InvalidMove, "adjustment needs a reason" if reason.to_s.strip.empty?
      diff = counted - balance(sku)
      return nil if diff.zero?
      post([[sku, :sellable, diff]], :"adjustment:#{reason}", nil, by)
    end

    private

    # All moves in one call succeed or none do.
    def post(moves, reason, ref, by)
      raise InvalidMove, "every movement needs a user" if by.to_s.empty?
      after = Hash.new { |h, k| h[k] = balance(*k) }
      moves.each { |sku, bucket, q| after[[sku, bucket]] += q }
      bad = after.find { |_, v| v.negative? }
      raise InsufficientStock, "#{bad[0][0]} #{bad[0][1]} would go to #{bad[1]}" if bad

      now = Time.now
      created = moves.map do |sku, bucket, q|
        raise InvalidMove, "unknown bucket #{bucket}" unless BUCKETS.include?(bucket)
        Movement.new(sku: sku, bucket: bucket, qty: q, reason: reason, ref: ref, at: now, by: by)
      end
      @movements.concat(created)
      created
    end
  end

  # ------------------------------------------------------- customer ledger
  Entry = Struct.new(:customer_id, :date, :kind, :ref, :debit, :credit, :by, keyword_init: true)

  class CustomerLedger
    attr_reader :entries

    def initialize = @entries = []

    def opening_balance(cid, amount, date:, by:)
      add(cid, date, :opening, "OPENING", amount.positive? ? amount : 0, amount.negative? ? -amount : 0, by)
    end

    def invoice(inv, by:) = add(inv.customer_id, inv.date, :invoice, inv.number, inv.total, 0, by)

    def payment(cid, amount, date:, mode:, ref:, by:)
      raise ArgumentError, "payment must be positive" unless amount.positive?
      raise ArgumentError, "mode must be cash, upi or cheque" unless %i[cash upi cheque].include?(mode)
      add(cid, date, :"payment_#{mode}", ref, 0, amount, by)
    end

    def credit_note(cid, amount, date:, ref:, by:) = add(cid, date, :credit_note, ref, 0, amount, by)

    def balance(cid) = for_customer(cid).sum { |e| e.debit - e.credit }

    # Credits settle the oldest debits first. Returns what's still unpaid.
    def open_items(cid)
      debits = for_customer(cid).select { |e| e.debit.positive? }
                                .sort_by { |e| [e.date, e.ref.to_s] }
                                .map { |e| { ref: e.ref, date: e.date, amount: e.debit, due: e.debit } }
      pool = for_customer(cid).sum(&:credit)
      debits.each do |d|
        used = [pool, d[:due]].min
        d[:due] -= used
        pool -= used
      end
      debits.reject { |d| d[:due].zero? }
    end

    def ageing(cid, as_of:)
      buckets = { "0-30" => 0, "31-60" => 0, "61-90" => 0, "90+" => 0 }
      open_items(cid).each do |d|
        days = (as_of - d[:date]).to_i
        key = days <= 30 ? "0-30" : days <= 60 ? "31-60" : days <= 90 ? "61-90" : "90+"
        buckets[key] += d[:due]
      end
      buckets
    end

    private

    def for_customer(cid) = @entries.select { |e| e.customer_id == cid }

    def add(cid, date, kind, ref, debit, credit, by)
      raise InvalidMove, "every entry needs a user" if by.to_s.empty?
      e = Entry.new(customer_id: cid, date: date, kind: kind, ref: ref, debit: debit, credit: credit, by: by)
      @entries << e
      e
    end
  end

  # ------------------------------------------------------------- warranty
  module Warranty
    module_function

    def valid?(sold_on:, warranty_months:, today:)
      return false if warranty_months.to_i <= 0
      today <= (sold_on >> warranty_months)
    end
  end

  # --------------------------------------------------------- Tally export
  # Produces Tally "Import Data" XML. Ledger names must match the CA's
  # Tally company exactly; they are configurable here.
  class TallyExport
    DEFAULT_LEDGERS = {
      sales: "Sales - GST", cgst: "Output CGST", sgst: "Output SGST",
      igst: "Output IGST", round_off: "Round Off", cash: "Cash", bank: "Bank",
      purchase: "Purchase - GST", in_cgst: "Input CGST", in_sgst: "Input SGST", in_igst: "Input IGST",
      claims: "Warranty Claims Received"
    }.freeze

    def initialize(company:, ledgers: {})
      @company = company
      @l = DEFAULT_LEDGERS.merge(ledgers)
    end

    # invoices: [[Invoice, party_ledger_name], ...]
    # receipts: [{date:, ref:, party:, amount:, mode:}, ...]
    # credit_notes: [{date:, number:, party:, taxable:, cgst:, sgst:, igst:, total:}, ...]
    # purchases: [[Invoice-shaped bill, supplier_ledger_name], ...]
    # payments: [{date:, ref:, party:, amount:, mode:}] (money paid to suppliers)
    # claim_credits: [{date:, number:, party:, amount:}] (brand credit notes on warranty claims)
    def to_xml(invoices: [], receipts: [], credit_notes: [], purchases: [], payments: [], claim_credits: [])
      msgs = invoices.map { |inv, party| sales_voucher(inv, party) } +
             credit_notes.map { |cn| voucher("Credit Note", cn[:date], cn[:number], cn[:party], credit_note_entries(cn)) } +
             receipts.map { |r| receipt_voucher(r) } +
             purchases.map { |b, party| voucher("Purchase", b.date, b.number, party, purchase_entries(b, party)) } +
             payments.map { |pm| voucher("Payment", pm[:date], pm[:ref], pm[:party], payment_entries(pm)) } +
             claim_credits.map { |c| voucher("Journal", c[:date], c[:number], c[:party], claim_credit_entries(c)) }
      <<~XML
        <ENVELOPE>
         <HEADER><TALLYREQUEST>Import Data</TALLYREQUEST></HEADER>
         <BODY><IMPORTDATA>
          <REQUESTDESC><REPORTNAME>Vouchers</REPORTNAME>
           <STATICVARIABLES><SVCURRENTCOMPANY>#{esc(@company)}</SVCURRENTCOMPANY></STATICVARIABLES>
          </REQUESTDESC>
          <REQUESTDATA>
        #{msgs.join("\n")}
          </REQUESTDATA>
         </IMPORTDATA></BODY>
        </ENVELOPE>
      XML
    end

    # Each voucher's entries must sum to zero (Tally rejects it otherwise).
    def sales_entries(inv, party)
      e = [[party, -inv.total, true], [@l[:sales], inv.taxable, false]]
      e << [@l[:cgst], inv.cgst, false] if inv.cgst.positive?
      e << [@l[:sgst], inv.sgst, false] if inv.sgst.positive?
      e << [@l[:igst], inv.igst, false] if inv.igst.positive?
      # total = exact + round_off, so round-off sits on the credit side with
      # its own sign; a negative round-off is a debit (deemed positive).
      e << [@l[:round_off], inv.round_off, inv.round_off.negative?] unless inv.round_off.zero?
      e
    end

    # Supplier is credited with the bill total; purchases and input tax are debits.
    def purchase_entries(bill, party)
      e = [[party, bill.total, false], [@l[:purchase], -bill.taxable, true]]
      e << [@l[:in_cgst], -bill.cgst, true] if bill.cgst.positive?
      e << [@l[:in_sgst], -bill.sgst, true] if bill.sgst.positive?
      e << [@l[:in_igst], -bill.igst, true] if bill.igst.positive?
      e << [@l[:round_off], -bill.round_off, bill.round_off.positive?] unless bill.round_off.zero?
      e
    end

    def payment_entries(pm)
      cash_or_bank = pm[:mode] == :cash ? @l[:cash] : @l[:bank]
      [[pm[:party], -pm[:amount], true], [cash_or_bank, pm[:amount], false]]
    end

    # Journal: supplier debited (we owe less), claims ledger credited.
    def claim_credit_entries(c)
      [[c[:party], -c[:amount], true], [@l[:claims], c[:amount], false]]
    end

    # Mirror of a sale: party is credited, sales and output tax are reduced.
    def credit_note_entries(cn)
      raise ArgumentError, "credit note does not add up" unless cn[:total] == cn[:taxable] + cn[:cgst] + cn[:sgst] + cn[:igst]
      e = [[cn[:party], cn[:total], false], [@l[:sales], -cn[:taxable], true]]
      e << [@l[:cgst], -cn[:cgst], true] if cn[:cgst].positive?
      e << [@l[:sgst], -cn[:sgst], true] if cn[:sgst].positive?
      e << [@l[:igst], -cn[:igst], true] if cn[:igst].positive?
      e
    end

    private

    def sales_voucher(inv, party)
      voucher("Sales", inv.date, inv.number, party, sales_entries(inv, party))
    end

    def receipt_voucher(r)
      cash_or_bank = r[:mode] == :cash ? @l[:cash] : @l[:bank]
      entries = [[cash_or_bank, -r[:amount], true], [r[:party], r[:amount], false]]
      voucher("Receipt", r[:date], r[:ref], r[:party], entries)
    end

    def voucher(type, date, number, party, entries)
      lines = entries.map do |ledger, amt, deemed_positive|
        "     <ALLLEDGERENTRIES.LIST><LEDGERNAME>#{esc(ledger)}</LEDGERNAME>" \
          "<ISDEEMEDPOSITIVE>#{deemed_positive ? 'Yes' : 'No'}</ISDEEMEDPOSITIVE>" \
          "<AMOUNT>#{rupees(amt)}</AMOUNT></ALLLEDGERENTRIES.LIST>"
      end
      <<~V.chomp
           <TALLYMESSAGE xmlns:UDF="TallyUDF">
            <VOUCHER VCHTYPE="#{type}" ACTION="Create">
             <DATE>#{date.strftime('%Y%m%d')}</DATE>
             <VOUCHERTYPENAME>#{type}</VOUCHERTYPENAME>
             <VOUCHERNUMBER>#{esc(number)}</VOUCHERNUMBER>
             <PARTYLEDGERNAME>#{esc(party)}</PARTYLEDGERNAME>
        #{lines.join("\n")}
            </VOUCHER>
           </TALLYMESSAGE>
      V
    end

    def rupees(p)
      sign = p.negative? ? "-" : ""
      r, ps = p.abs.divmod(100)
      "#{sign}#{r}.#{ps.to_s.rjust(2, '0')}"
    end

    def esc(s)
      s.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")
    end
  end
end
