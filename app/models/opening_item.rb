# An opening balance (debt brought in from the old books) behaves like a bill: it ages from its
# date, payments are matched to it first-in-first-out, and it shows in dues until cleared.
class OpeningItem
  attr_reader :entry, :paid_paise

  def initialize(entry, paid_paise)
    @entry, @paid_paise = entry, paid_paise.to_i
  end

  def id = entry.id
  def number = "Opening balance"
  def customer = entry.party
  def customer_id = entry.party_id
  def invoice_date = entry.entry_date
  def due_date = entry.entry_date
  def total_paise = entry.debit_paise
  def credited_paise = 0
  def outstanding_paise = [total_paise - paid_paise, 0].max
  def unpaid? = outstanding_paise.positive?
  def overdue?(on = Date.current) = unpaid? && due_date < on
  def days_overdue(on = Date.current) = overdue?(on) ? (on - due_date).to_i : 0
  def payment_state = unpaid? ? (overdue? ? "overdue" : "unpaid") : "paid"
  def posted? = true
end
