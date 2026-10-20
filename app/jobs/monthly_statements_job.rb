# 1st of the month: last month's statement to every customer who traded or owes.
class MonthlyStatementsJob < ApplicationJob
  def perform(month_start = Date.current.prev_month.beginning_of_month)
    Current.device = "scheduler"
    from, to = month_start, month_start.end_of_month
    ids = LedgerEntry.where(party_type: "Customer", entry_date: from..to).distinct.pluck(:party_id)
    Customer.active.where(id: ids).or(Customer.active.where(id: Customer.with_balance.to_a.select { _1.balance_paise.positive? }.map(&:id))).find_each do |c|
      WhatsappNotifier.statement(c, from: from, to: to)
    end
  end
end
