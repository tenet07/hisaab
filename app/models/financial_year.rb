# Indian financial year: April to March, written "2026-27".
module FinancialYear
  module_function

  def for(date)
    date = date.to_date
    start = date.month >= 4 ? date.year : date.year - 1
    "#{start}-#{(start + 1).to_s[-2..]}"
  end

  def range(fy = self.for(Date.current))
    start = fy.to_s[0, 4].to_i
    Date.new(start, 4, 1)..Date.new(start + 1, 3, 31)
  end
end
