require "builder"

module Reports
  # Tally Prime / ERP 9 import file (XML envelope): party ledger masters, then Sales, Credit Note,
  # Receipt and Purchase vouchers. Ledger names match a standard Tally GST setup.
  class Tally
    LEDGERS = { sales: "Sales - GST", purchase: "Purchase - GST", cgst: "Output CGST", sgst: "Output SGST", igst: "Output IGST",
                in_cgst: "Input CGST", in_sgst: "Input SGST", in_igst: "Input IGST", round: "Round Off", cash: "Cash", bank: "Bank" }.freeze

    def initialize(from, to)
      @from, @to = from, to
    end

    def to_xml
      x = Builder::XmlMarkup.new(indent: 1)
      x.instruct!
      x.ENVELOPE do
        x.HEADER { x.TALLYREQUEST "Import Data" }
        x.BODY do
          x.IMPORTDATA do
            x.REQUESTDESC { x.REPORTNAME "All Masters" }
            x.REQUESTDATA do
              parties.each { |p| ledger_master(x, p) }
            end
          end
          x.IMPORTDATA do
            x.REQUESTDESC { x.REPORTNAME "Vouchers" }
            x.REQUESTDATA do
              Invoice.posted.where(invoice_date: @from..@to).includes(:customer).order(:invoice_date, :id).each { sales(x, _1) }
              ::CreditNote.where(note_date: @from..@to).includes(:customer, :invoice).each { credit_note(x, _1) }
              Payment.cleared.where(received_on: @from..@to).includes(:customer).each { receipt(x, _1) }
              Purchase.where(bill_date: @from..@to).includes(:supplier).each { purchase(x, _1) }
            end
          end
        end
      end
    end

    private

    def parties
      ids = Invoice.where(invoice_date: @from..@to).distinct.pluck(:customer_id) + Payment.where(received_on: @from..@to).distinct.pluck(:customer_id)
      Customer.where(id: ids.uniq)
    end

    def name(c) = "#{c.shop_name} (#{c.code})"
    def amt(p) = format("%.2f", p / 100.0)
    def tdate(d) = d.strftime("%Y%m%d")

    def ledger_master(x, c)
      x.TALLYMESSAGE("xmlns:UDF" => "TallyUDF") do
        x.LEDGER(NAME: name(c), ACTION: "Create") do
          x.NAME name(c)
          x.PARENT "Sundry Debtors"
          x.ISBILLWISEON "Yes"
          x.PARTYGSTIN c.gstin if c.gstin
          x.GSTREGISTRATIONTYPE c.gstin ? "Regular" : "Unregistered"
          x.LEDSTATENAME GstStates::NAMES[c.state_code || ShopSetting.current.state_code]
          x.LEDGERMOBILE c.phone
        end
      end
    end

    # In Tally XML, debits are negative amounts with ISDEEMEDPOSITIVE Yes
    def entry(x, ledger, paise, debit:, bill: nil, bill_type: "New Ref")
      x.tag!("ALLLEDGERENTRIES.LIST") do
        x.LEDGERNAME ledger
        x.ISDEEMEDPOSITIVE debit ? "Yes" : "No"
        x.AMOUNT debit ? "-#{amt(paise)}" : amt(paise)
        if bill
          x.tag!("BILLALLOCATIONS.LIST") { x.NAME bill; x.BILLTYPE bill_type; x.AMOUNT debit ? "-#{amt(paise)}" : amt(paise) }
        end
      end
    end

    def voucher(x, type, number, date, party, narration)
      x.TALLYMESSAGE("xmlns:UDF" => "TallyUDF") do
        x.VOUCHER(VCHTYPE: type, ACTION: "Create") do
          x.DATE tdate(date)
          x.VOUCHERTYPENAME type
          x.VOUCHERNUMBER number
          x.PARTYLEDGERNAME party
          x.NARRATION narration
          yield
        end
      end
    end

    def sales(x, i)
      voucher(x, "Sales", i.number, i.invoice_date, name(i.customer), "GST invoice #{i.number}") do
        entry(x, name(i.customer), i.total_paise, debit: true, bill: i.number)
        entry(x, LEDGERS[:sales], i.taxable_paise, debit: false)
        entry(x, LEDGERS[:cgst], i.cgst_paise, debit: false) if i.cgst_paise.positive?
        entry(x, LEDGERS[:sgst], i.sgst_paise, debit: false) if i.sgst_paise.positive?
        entry(x, LEDGERS[:igst], i.igst_paise, debit: false) if i.igst_paise.positive?
        entry(x, LEDGERS[:round], i.round_off_paise.abs, debit: i.round_off_paise.negative?) unless i.round_off_paise.zero?
      end
    end

    def credit_note(x, n)
      voucher(x, "Credit Note", n.number, n.note_date, name(n.customer), "#{n.reason_label} on #{n.invoice.number}") do
        entry(x, name(n.customer), n.total_paise, debit: false, bill: n.invoice.number, bill_type: "Agst Ref")
        entry(x, LEDGERS[:sales], n.taxable_paise, debit: true)
        entry(x, LEDGERS[:cgst], n.cgst_paise, debit: true) if n.cgst_paise.positive?
        entry(x, LEDGERS[:sgst], n.sgst_paise, debit: true) if n.sgst_paise.positive?
        entry(x, LEDGERS[:igst], n.igst_paise, debit: true) if n.igst_paise.positive?
      end
    end

    def receipt(x, p)
      voucher(x, "Receipt", p.number, p.received_on, name(p.customer), "#{p.mode_label} #{p.reference}".strip) do
        entry(x, p.mode == "cash" ? LEDGERS[:cash] : LEDGERS[:bank], p.amount_paise, debit: true)
        p.allocations.includes(:invoice).each { |a| entry(x, name(p.customer), a.amount_paise, debit: false, bill: a.target_label, bill_type: "Agst Ref") }
        entry(x, name(p.customer), p.unallocated_paise, debit: false, bill: p.number, bill_type: "Advance") if p.unallocated_paise.positive?
      end
    end

    def purchase(x, p)
      inter = (p.supplier.state_code || ShopSetting.current.state_code) != ShopSetting.current.state_code
      voucher(x, "Purchase", p.bill_no, p.bill_date, p.supplier.name, "Supplier bill #{p.bill_no}") do
        entry(x, p.supplier.name, p.total_paise, debit: false, bill: p.bill_no)
        entry(x, LEDGERS[:purchase], p.taxable_paise, debit: true)
        if inter then entry(x, LEDGERS[:in_igst], p.tax_paise, debit: true)
        else
          entry(x, LEDGERS[:in_cgst], p.tax_paise / 2, debit: true)
          entry(x, LEDGERS[:in_sgst], p.tax_paise - p.tax_paise / 2, debit: true)
        end
      end
    end
  end
end
