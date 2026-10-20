# Brings a customer's balance over from the old books. Money owed becomes an opening debit that
# payments are matched to; an advance becomes an opening payment that new bills draw from.
module OpeningBalance
  module_function

  def post!(customer, paise, narration: "Opening balance")
    paise = paise.to_i
    return if paise.zero?
    if paise.positive?
      LedgerEntry.create!(party: customer, entry_date: Date.current, entry_type: "opening", narration: narration, debit_paise: paise)
      Payments::Allocate.call(customer)
    else
      Payments::Record.call(customer: customer, amount_paise: -paise, mode: "opening", entry_type: "opening", notes: narration)
    end
  end
end
